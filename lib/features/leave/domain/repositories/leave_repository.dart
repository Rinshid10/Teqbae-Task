import '../../../../core/utils/cached.dart';
import '../../../../core/utils/result.dart';
import '../entities/leave.dart';

abstract class LeaveRepository {
  Future<Result<Cached<List<LeaveBalance>>>> getBalances({bool refresh = true});

  Future<Result<Cached<List<LeaveRequest>>>> getRequests({bool refresh = true});

  /// Sends a request to the server. Never queued: leave needs a connection.
  /// A 422 comes back as RejectedFailure with `fieldErrors` filled in.
  Future<Result<LeaveRequest>> submit(LeaveDraft draft);
}
