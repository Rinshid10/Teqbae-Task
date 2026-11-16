import '../../../../core/error/failures.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/utils/result.dart';
import '../../../attendance/domain/repositories/attendance_repository.dart';
import '../entities/outbox_event.dart';
import '../repositories/attendance_event_sender.dart';
import '../repositories/outbox_repository.dart';

/// What one sync run did.
class SyncRunResult {
  const SyncRunResult({
    this.synced = 0,
    this.rejected = 0,
    this.blockedBy,
    this.skipped = false,
  });

  final int synced;
  final int rejected;

  /// Set when the run stopped early on a temporary failure. Events are still
  /// queued and the caller should retry later.
  final Failure? blockedBy;

  /// True when another run was already in progress and this one did nothing.
  final bool skipped;
}

/// Sends the outbox to the server: one event at a time, strictly in `seq`
/// order.
///
/// The three outcomes for each event:
///   accepted (or already there) -> SYNCED, move on to the next
///   rejected by a business rule -> REJECTED, move on to the next
///   temporary failure           -> back to PENDING and STOP the whole run
///
/// Stopping on a temporary failure is what preserves ordering: a CHECK_OUT
/// must never reach the server before its CHECK_IN, so nothing behind a
/// stuck event is attempted.
class ProcessOutbox {
  ProcessOutbox({
    required OutboxRepository outbox,
    required AttendanceEventSender sender,
    required AttendanceRepository attendance,
  })  : _outbox = outbox,
        _sender = sender,
        _attendance = attendance;

  final OutboxRepository _outbox;
  final AttendanceEventSender _sender;
  final AttendanceRepository _attendance;

  /// Mutex. Dart runs on one thread, so a plain flag set before the first
  /// `await` is enough to stop two runs from interleaving.
  bool _running = false;

  Future<SyncRunResult> call() async {
    if (_running) return const SyncRunResult(skipped: true);
    _running = true;

    var synced = 0;
    var rejected = 0;
    Failure? blockedBy;

    try {
      // Re-query each round instead of loading the list once, so an event
      // created while this run is in progress is picked up too.
      while (true) {
        final event = await _outbox.nextUnsent();
        if (event == null) break;

        await _outbox.markSyncing(event.seq);
        final result = await _sender.send(event);

        switch (result) {
          case Success(:final value):
            await _outbox.markSynced(event.seq, serverRecordId: value);
            synced++;

          case Fail(failure: RejectedFailure(:final message)):
            await _outbox.markRejected(event.seq, reason: message);
            rejected++;
            if (event.type == AttendanceEventType.checkIn) {
              // Its check-out can never succeed now; reject it too rather
              // than sending a request we know will fail.
              await _outbox.rejectUnsentCheckOut(
                event.workDate,
                reason: AppStrings.checkInWasRejected,
              );
            }

          case Fail(:final failure):
            // Network, timeout or 5xx. The event keeps its event_id, so if
            // the server did save it before a timeout, the retry is answered
            // with the original record instead of creating a second one.
            await _outbox.markAttemptFailed(event.seq, error: failure.message);
            blockedBy = failure;
        }
        if (blockedBy != null) break;
      }

      if (synced > 0) {
        // Pull the server's version of the records into the cache. If this
        // fails the UI still shows the SYNCED events from the outbox.
        await _attendance.getRecords(refresh: true);
      }
    } finally {
      _running = false;
    }

    return SyncRunResult(synced: synced, rejected: rejected, blockedBy: blockedBy);
  }
}

/// Wait before retrying after [consecutiveFailures] failed runs:
/// 2s, 4s, 8s, 16s, 32s, then 60s at most.
Duration backoffDelay(int consecutiveFailures) {
  if (consecutiveFailures <= 0) return Duration.zero;
  // Clamp the exponent so the shift can never overflow.
  final exponent = consecutiveFailures.clamp(1, 6);
  final seconds = 1 << exponent; // 2^exponent
  return Duration(seconds: seconds > 60 ? 60 : seconds);
}
