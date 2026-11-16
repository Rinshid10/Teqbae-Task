import '../../../../core/error/failures.dart';
import '../../../../core/network/error_mapper.dart';
import '../../../../core/utils/result.dart';
import '../../../attendance/data/datasources/attendance_remote_data_source.dart';
import '../../domain/entities/outbox_event.dart';
import '../../domain/repositories/attendance_event_sender.dart';
import '../models/outbox_event_model.dart';

class AttendanceEventSenderImpl implements AttendanceEventSender {
  const AttendanceEventSenderImpl(this._remote);

  final AttendanceRemoteDataSource _remote;

  /// Error codes meaning "I already have THIS event" — as opposed to
  /// ATTENDANCE_ALREADY_EXISTS, which means a DIFFERENT event got there
  /// first and this one really is refused.
  static const _duplicateCodes = {'DUPLICATE', 'DUPLICATE_EVENT'};

  @override
  Future<Result<String?>> send(OutboxEvent event) async {
    try {
      final json = await _remote.postEvent(OutboxEventModel.fromEntity(event));
      // 201 (created) and 200 (idempotent replay of an earlier attempt)
      // both arrive here: either way the server has the event.
      return Success(json['id'] as String?);
    } catch (error) {
      final failure = toFailure(error);
      if (failure is RejectedFailure && _duplicateCodes.contains(failure.code)) {
        // Some servers answer a repeated idempotency key with 409 instead
        // of replaying the original response. The event is on the server,
        // which is all "synced" means.
        return const Success(null);
      }
      return Fail(failure);
    }
  }
}
