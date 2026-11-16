import '../../../../core/utils/result.dart';
import '../entities/outbox_event.dart';

/// Delivers one outbox event to the server.
abstract class AttendanceEventSender {
  /// Success carries the server's record id (may be null if the server
  /// only confirmed it already had the event).
  ///
  /// Failures the sync engine relies on:
  ///   RejectedFailure                      -> the server said no; never retry
  ///   Network / Timeout / ServerFailure    -> temporary; retry later
  Future<Result<String?>> send(OutboxEvent event);
}
