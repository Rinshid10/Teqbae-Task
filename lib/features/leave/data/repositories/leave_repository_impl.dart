import '../../../../core/network/cached_fetch.dart';
import '../../../../core/network/error_mapper.dart';
import '../../../../core/utils/cached.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/leave.dart';
import '../../domain/repositories/leave_repository.dart';
import '../datasources/leave_local_data_source.dart';
import '../datasources/leave_remote_data_source.dart';
import '../models/leave_models.dart';

class LeaveRepositoryImpl implements LeaveRepository {
  const LeaveRepositoryImpl({
    required LeaveRemoteDataSource remote,
    required LeaveLocalDataSource local,
    required Clock clock,
  })  : _remote = remote,
        _local = local,
        _clock = clock;

  final LeaveRemoteDataSource _remote;
  final LeaveLocalDataSource _local;
  final Clock _clock;

  @override
  Future<Result<Cached<List<LeaveBalance>>>> getBalances({bool refresh = true}) {
    return cachedFetch<List<LeaveBalance>>(
      refresh: refresh,
      clock: _clock,
      fetchRemote: _remote.fetchBalances,
      saveCache: (balances, at) =>
          _local.replaceBalances(balances.cast<LeaveBalanceModel>(), at),
      readCache: () async {
        final fetchedAt = await _local.balancesFetchedAt();
        if (fetchedAt == null) return null;
        return Cached(await _local.readBalances(),
            fetchedAt: fetchedAt, isStale: true);
      },
    );
  }

  @override
  Future<Result<Cached<List<LeaveRequest>>>> getRequests({bool refresh = true}) {
    return cachedFetch<List<LeaveRequest>>(
      refresh: refresh,
      clock: _clock,
      fetchRemote: _remote.fetchRequests,
      saveCache: (requests, at) =>
          _local.replaceRequests(requests.cast<LeaveRequestModel>(), at),
      readCache: () async {
        final fetchedAt = await _local.requestsFetchedAt();
        if (fetchedAt == null) return null;
        return Cached(await _local.readRequests(),
            fetchedAt: fetchedAt, isStale: true);
      },
    );
  }

  @override
  Future<Result<LeaveRequest>> submit(LeaveDraft draft) async {
    try {
      final created = await _remote.submit(draft);
      // The new request changes both the list and the balance, so refresh
      // both caches. Best effort: the request itself already succeeded.
      await getRequests(refresh: true);
      await getBalances(refresh: true);
      return Success(created);
    } catch (error) {
      return Fail(toFailure(error));
    }
  }
}
