import 'dart:async';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_messenger.dart';
import '../../../attendance/presentation/models/attendance_ui.dart';
import '../../domain/entities/outbox_event.dart';
import '../../domain/usecases/get_outbox_events.dart';
import '../sync_service.dart';

/// One event waiting in the queue.
class QueueItemUi {
  const QueueItemUi({
    required this.position,
    required this.title,
    required this.timeLabel,
    required this.detail,
    required this.idLabel,
  });

  final String position; // "1"
  final String title; // "Check In"
  final String timeLabel; // "16 Nov, 09:12 AM"

  /// "Waiting for its turn" or "Tried 2 times · (last error)".
  final String detail;

  /// Short form of the idempotency key, e.g. "ID #920A".
  final String idLabel;
}

/// One finished event in the history list.
class SyncHistoryUi {
  const SyncHistoryUi({
    required this.title,
    required this.subtitle,
    required this.rejected,
  });

  final String title; // "13 Nov Check-in"
  final String subtitle;

  /// Set for a rejected event (the row then opens the reason sheet);
  /// null for a synced one.
  final RejectedEventUi? rejected;
}

class SyncCenterData {
  const SyncCenterData({required this.queue, required this.history});

  final List<QueueItemUi> queue;
  final List<SyncHistoryUi> history;
}

/// Drives the Sync Center screen: the pending queue in the order it will be
/// sent, and what happened to recent events.
class SyncCenterController extends GetxController {
  SyncCenterController({
    required GetOutboxEvents getEvents,
    required SyncService sync,
    required AppFormat format,
    required AttendanceUiMapper mapper,
  })  : _getEvents = getEvents,
        _sync = sync,
        _format = format,
        _mapper = mapper;

  final GetOutboxEvents _getEvents;
  final SyncService _sync;
  final AppFormat _format;
  final AttendanceUiMapper _mapper;

  static const historyCount = 8;

  final data = const SyncCenterData(queue: [], history: []).obs;

  RxBool get isSyncing => _sync.isSyncing;
  RxBool get isOnline => _sync.isOnline;
  RxInt get pendingCount => _sync.pendingCount;

  /// "Last synced 10:24 AM", or a note that nothing has synced yet.
  final lastSyncedLabel = AppStrings.notSyncedYet.obs;

  StreamSubscription<void>? _subscription;
  Worker? _lastSyncedWorker;

  @override
  void onInit() {
    super.onInit();
    _subscription = _getEvents.changes.listen((_) => _load());
    _lastSyncedWorker = ever<DateTime?>(_sync.lastSyncedAt, _showLastSynced);
    _showLastSynced(_sync.lastSyncedAt.value);
    _load();
  }

  void _showLastSynced(DateTime? at) {
    lastSyncedLabel.value = at == null
        ? AppStrings.notSyncedYet
        : AppStrings.lastSyncedAt(_format.time(at));
  }

  Future<void> _load() async {
    final events = await _getEvents();
    if (isClosed) return;

    // The queue keeps outbox order (oldest first): that is the order the
    // events will be sent in.
    final unsent = events.where((e) => e.status.isUnsent).toList();
    // History is newest first.
    final finished =
        events.where((e) => !e.status.isUnsent).toList().reversed;

    data.value = SyncCenterData(
      queue: [
        for (var i = 0; i < unsent.length; i++)
          QueueItemUi(
            position: '${i + 1}',
            title: _typeLabel(unsent[i]),
            timeLabel: _format.dayAndTime(unsent[i].occurredAt),
            detail: unsent[i].attempts == 0
                ? AppStrings.queueWaiting
                : AppStrings.queueRetrying(
                    unsent[i].attempts, unsent[i].lastError),
            idLabel: AppStrings.eventId(_shortId(unsent[i].eventId)),
          ),
      ],
      history: [
        for (final event in finished.take(historyCount))
          SyncHistoryUi(
            title: AppStrings.historyTitle(
              _format.dayMonth(event.workDate),
              event.type == AttendanceEventType.checkIn
                  ? AppStrings.checkInLabel
                  : AppStrings.checkOutLabel,
            ),
            subtitle: event.status == SyncStatus.rejected
                ? AppStrings.historyRejected
                : AppStrings.historySynced(_format.time(event.occurredAt)),
            rejected: event.status == SyncStatus.rejected
                ? _mapper.rejectedEvent(event)
                : null,
          ),
      ],
    );
  }

  static String _typeLabel(OutboxEvent event) =>
      event.type == AttendanceEventType.checkIn
          ? AppStrings.checkIn
          : AppStrings.checkOut;

  /// Last four characters of the UUID, upper-cased: enough to match an
  /// event against the server log without showing the whole key.
  static String _shortId(String eventId) {
    final tail =
        eventId.length <= 4 ? eventId : eventId.substring(eventId.length - 4);
    return tail.toUpperCase();
  }

  /// Runs a sync. Returns null when it went through; otherwise the reason
  /// it could not, which the view shows in a sheet (a failure the user
  /// asked about deserves more than a passing snackbar).
  Future<String?> syncNow() async {
    HapticFeedback.lightImpact();
    final result = await _sync.syncNow();
    if (result.skipped) return null;
    if (result.blockedBy != null) return result.blockedBy!.message;
    AppMessenger.show(result.rejected > 0
        ? AppStrings.syncSomeRejected
        : AppStrings.syncAllDone);
    return null;
  }

  @override
  void onClose() {
    _subscription?.cancel();
    _lastSyncedWorker?.dispose();
    super.onClose();
  }
}
