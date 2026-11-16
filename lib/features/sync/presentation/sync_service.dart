import 'dart:async';

import 'package:get/get.dart';

import '../../../core/error/failures.dart';
import '../../../core/network/network_info.dart';
import '../domain/repositories/outbox_repository.dart';
import '../domain/usecases/process_outbox.dart';

/// Decides WHEN the outbox is sent. HOW it is sent (ordering, statuses,
/// rejection cascade) lives in the ProcessOutbox use case.
///
/// Triggers:
///   - app start
///   - connectivity restored (debounced 2 s, as networks flap on reconnect)
///   - "Sync Now"
///   - right after a check-in / check-out is recorded
///   - a retry timer with exponential backoff after a temporary failure
///
/// Registered once, permanently, so it outlives every screen. It only runs
/// while the app process is alive; syncing while the app is terminated
/// would need WorkManager / BGTaskScheduler and is out of scope.
class SyncService extends GetxService {
  SyncService({
    required ProcessOutbox processOutbox,
    required OutboxRepository outbox,
    required NetworkInfo networkInfo,
    this.reconnectDebounce = const Duration(seconds: 2),
    this.backoff = backoffDelay,
    DateTime Function()? now,
  })  : _processOutbox = processOutbox,
        _outbox = outbox,
        _networkInfo = networkInfo,
        _now = now ?? (() => DateTime.now().toUtc());

  final ProcessOutbox _processOutbox;
  final OutboxRepository _outbox;
  final NetworkInfo _networkInfo;
  final DateTime Function() _now;
  final Duration reconnectDebounce;

  /// How long to wait after N failed runs in a row. Injectable so tests can
  /// use milliseconds instead of waiting real seconds.
  final Duration Function(int consecutiveFailures) backoff;

  // Observable state for the UI.
  final isSyncing = false.obs;
  final pendingCount = 0.obs;

  /// Whether the device has a connection (drives the Online/Offline labels).
  final isOnline = true.obs;

  /// When events were last delivered to the server. Kept in memory only,
  /// so it is empty until the first sync after the app starts.
  final lastSyncedAt = Rxn<DateTime>();

  /// Why the last run stopped early; null after a clean run.
  final lastFailure = Rxn<Failure>();

  int _consecutiveFailures = 0;
  Timer? _retryTimer;
  Timer? _debounceTimer;
  StreamSubscription<void>? _outboxSubscription;
  StreamSubscription<bool>? _networkSubscription;

  @override
  void onInit() {
    super.onInit();
    _outboxSubscription = _outbox.changes.listen((_) => _refreshPendingCount());
    _networkSubscription = _networkInfo.onStatusChange.listen(_onConnectivity);
    _networkInfo.isConnected.then((value) => isOnline.value = value);
    syncNow(); // app start: deliver whatever survived the last session
  }

  void _onConnectivity(bool connected) {
    isOnline.value = connected;
    // Restart the wait on every change; only a connection that stays up
    // for the whole debounce period triggers a sync.
    _debounceTimer?.cancel();
    if (!connected) return;
    _debounceTimer = Timer(reconnectDebounce, syncNow);
  }

  /// Runs the outbox once. Safe to call from anywhere at any time: if a run
  /// is already in progress this returns immediately with `skipped`.
  Future<SyncRunResult> syncNow() async {
    if (isSyncing.value) return const SyncRunResult(skipped: true);
    _retryTimer?.cancel();
    isSyncing.value = true;
    try {
      final result = await _processOutbox();
      if (result.skipped) return result;

      if (result.blockedBy != null) {
        _consecutiveFailures++;
        lastFailure.value = result.blockedBy;
        _scheduleRetry();
      } else {
        _consecutiveFailures = 0;
        lastFailure.value = null;
        // Only a run that delivered something counts as "synced".
        if (result.synced > 0) lastSyncedAt.value = _now();
      }
      return result;
    } catch (_) {
      // A local database error. Treat like a temporary failure.
      _consecutiveFailures++;
      _scheduleRetry();
      return const SyncRunResult(blockedBy: CacheFailure());
    } finally {
      await _refreshPendingCount();
      isSyncing.value = false;
    }
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(backoff(_consecutiveFailures), () async {
      // No point retrying with no network: the connectivity listener will
      // start a run as soon as the connection is back.
      if (await _networkInfo.isConnected) syncNow();
    });
  }

  Future<void> _refreshPendingCount() async {
    try {
      pendingCount.value = await _outbox.unsentCount();
    } catch (_) {
      // Keep the previous number rather than crash a background listener.
    }
  }

  @override
  void onClose() {
    _retryTimer?.cancel();
    _debounceTimer?.cancel();
    _outboxSubscription?.cancel();
    _networkSubscription?.cancel();
    super.onClose();
  }
}
