import 'dart:async';

import '../../../../core/error/failures.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/outbox_event.dart';
import '../../domain/repositories/outbox_repository.dart';
import '../datasources/outbox_local_data_source.dart';
import '../models/outbox_event_model.dart';

class OutboxRepositoryImpl implements OutboxRepository {
  OutboxRepositoryImpl({
    required OutboxLocalDataSource local,
    required Clock clock,
  })  : _local = local,
        _clock = clock;

  final OutboxLocalDataSource _local;
  final Clock _clock;

  /// Broadcast: several screens listen at once (dashboard, attendance, the
  /// sync service's pending counter).
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  @override
  Future<Result<OutboxEvent>> add({
    required String eventId,
    required AttendanceEventType type,
    required DateTime occurredAt,
    required String workDate,
    required double lat,
    required double lng,
    required double? accuracy,
  }) async {
    try {
      final stored = await _local.insert(OutboxEventModel(
        seq: 0, // ignored on insert; Hive assigns the real one
        eventId: eventId,
        type: type,
        occurredAt: occurredAt,
        workDate: workDate,
        lat: lat,
        lng: lng,
        accuracy: accuracy,
        status: SyncStatus.pending,
        attempts: 0,
        lastError: null,
        serverRecordId: null,
        createdAt: _clock.nowUtc(),
      ));
      _notify();
      return Success(stored);
    } on DuplicateOutboxEventException {
      return const Fail(
          ValidationFailure(AppStrings.duplicateEvent, code: 'DUPLICATE_EVENT'));
    } catch (_) {
      return const Fail(CacheFailure(AppStrings.cacheError));
    }
  }

  @override
  Future<List<OutboxEvent>> all() => _local.readAll();

  @override
  Future<List<OutboxEvent>> forWorkDate(String workDate) =>
      _local.readForWorkDate(workDate);

  @override
  Future<OutboxEvent?> nextUnsent() => _local.readNextUnsent();

  @override
  Future<int> unsentCount() => _local.countUnsent();

  @override
  Future<void> markSyncing(int seq) async {
    await _local.update(seq, {'status': SyncStatus.syncing.wire});
    _notify();
  }

  @override
  Future<void> markSynced(int seq, {required String? serverRecordId}) async {
    await _local.update(seq, {
      'status': SyncStatus.synced.wire,
      'server_record_id': serverRecordId,
      'last_error': null,
    });
    _notify();
  }

  @override
  Future<void> markRejected(int seq, {required String reason}) async {
    await _local.update(
        seq, {'status': SyncStatus.rejected.wire, 'last_error': reason});
    _notify();
  }

  @override
  Future<void> markAttemptFailed(int seq, {required String error}) async {
    await _local.recordFailedAttempt(seq, error);
    _notify();
  }

  @override
  Future<void> rejectUnsentCheckOut(
    String workDate, {
    required String reason,
  }) async {
    await _local.rejectUnsentCheckOut(workDate, reason);
    _notify();
  }

  Future<void> dispose() => _changes.close();
}
