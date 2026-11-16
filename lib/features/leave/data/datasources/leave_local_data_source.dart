import '../../../../core/database/app_database.dart';
import '../models/leave_models.dart';

/// Cached leave balances and leave requests, each kept in Hive as one list
/// under its own key.
class LeaveLocalDataSource {
  const LeaveLocalDataSource(this._database);

  final AppDatabase _database;

  static const _balances = AppDatabase.leaveBalancesKey;
  static const _requests = AppDatabase.leaveRequestsKey;

  // ---- balances -----------------------------------------------------------

  Future<List<LeaveBalanceModel>> readBalances() async {
    final entry = _database.readCache(_balances);
    if (entry == null) return const [];
    return AppDatabase.rows(entry.data).map(LeaveBalanceModel.fromDb).toList()
      ..sort((a, b) => a.type.wire.compareTo(b.type.wire));
  }

  Future<DateTime?> balancesFetchedAt() async =>
      _database.readCache(_balances)?.fetchedAt;

  Future<void> replaceBalances(
    List<LeaveBalanceModel> balances,
    DateTime fetchedAt,
  ) {
    return _database.writeCache(
      _balances,
      [for (final balance in balances) balance.toDb()],
      fetchedAt,
    );
  }

  // ---- requests -----------------------------------------------------------

  /// Newest start date first.
  Future<List<LeaveRequestModel>> readRequests() async {
    final entry = _database.readCache(_requests);
    if (entry == null) return const [];
    return AppDatabase.rows(entry.data).map(LeaveRequestModel.fromDb).toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
  }

  Future<DateTime?> requestsFetchedAt() async =>
      _database.readCache(_requests)?.fetchedAt;

  Future<void> replaceRequests(
    List<LeaveRequestModel> requests,
    DateTime fetchedAt,
  ) {
    return _database.writeCache(
      _requests,
      [for (final request in requests) request.toDb()],
      fetchedAt,
    );
  }
}
