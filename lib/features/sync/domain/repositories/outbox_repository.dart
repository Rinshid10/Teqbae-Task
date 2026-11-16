import '../../../../core/utils/result.dart';
import '../entities/outbox_event.dart';

/// The queue of attendance events waiting to reach the server.
abstract class OutboxRepository {
  /// Stores a new PENDING event. Fails (instead of creating a duplicate) if a
  /// live event of the same type already exists for that working day.
  Future<Result<OutboxEvent>> add({
    required String eventId,
    required AttendanceEventType type,
    required DateTime occurredAt,
    required String workDate,
    required double lat,
    required double lng,
    required double? accuracy,
  });

  /// Every event, oldest first.
  Future<List<OutboxEvent>> all();

  Future<List<OutboxEvent>> forWorkDate(String workDate);

  /// The unsent event with the lowest seq, or null when the queue is empty.
  Future<OutboxEvent?> nextUnsent();

  Future<int> unsentCount();

  Future<void> markSyncing(int seq);

  Future<void> markSynced(int seq, {required String? serverRecordId});

  Future<void> markRejected(int seq, {required String reason});

  /// A temporary failure: back to PENDING, attempts + 1, error remembered.
  Future<void> markAttemptFailed(int seq, {required String error});

  /// Rejects the unsent CHECK_OUT of [workDate] (used when its CHECK_IN was
  /// rejected — a check-out with no check-in can never be accepted).
  Future<void> rejectUnsentCheckOut(String workDate, {required String reason});

  /// Fires after every change, so screens can re-read and re-render.
  Stream<void> get changes;
}
