import '../../../../core/utils/cached.dart';
import '../../../../core/utils/result.dart';
import '../entities/leave.dart';
import '../repositories/leave_repository.dart';

/// Balances and requests in one call, fetched in parallel.
class GetLeaveOverview {
  const GetLeaveOverview(this._repository);

  final LeaveRepository _repository;

  Future<Result<Cached<LeaveOverview>>> call({bool refresh = true}) async {
    final balancesFuture = _repository.getBalances(refresh: refresh);
    final requestsFuture = _repository.getRequests(refresh: refresh);
    final balances = await balancesFuture;
    final requests = await requestsFuture;

    // Both halves are needed to show the screen; if either has neither
    // fresh nor cached data, the whole overview fails.
    switch ((balances, requests)) {
      case (Fail(:final failure), _) || (_, Fail(:final failure)):
        return Fail(failure);
      case (Success(value: final b), Success(value: final r)):
        return Success(Cached(
          LeaveOverview(balances: b.value, requests: r.value),
          // Report the older of the two timestamps: "last updated" must not
          // claim to be newer than the oldest piece on screen.
          fetchedAt: _older(b.fetchedAt, r.fetchedAt),
          isStale: b.isStale || r.isStale,
          refreshError: b.refreshError ?? r.refreshError,
        ));
    }
  }

  static DateTime? _older(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a ?? b;
    return a.isBefore(b) ? a : b;
  }
}
