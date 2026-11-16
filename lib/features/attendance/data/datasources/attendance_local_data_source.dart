import '../../../../core/database/app_database.dart';
import '../models/attendance_record_model.dart';

/// The cached attendance history, kept in Hive as one list under one key.
class AttendanceLocalDataSource {
  const AttendanceLocalDataSource(this._database);

  final AppDatabase _database;

  static const _key = AppDatabase.attendanceKey;

  /// Newest first.
  Future<List<AttendanceRecordModel>> readAll() async {
    final entry = _database.readCache(_key);
    if (entry == null) return const [];
    return AppDatabase.rows(entry.data)
        .map(AttendanceRecordModel.fromDb)
        .toList()
      // yyyy-MM-dd sorts correctly as plain text.
      ..sort((a, b) => b.workDate.compareTo(a.workDate));
  }

  Future<AttendanceRecordModel?> readForWorkDate(String workDate) async {
    final records = await readAll();
    return records.where((r) => r.workDate == workDate).firstOrNull;
  }

  /// Null means "never fetched" (as opposed to fetched and empty).
  Future<DateTime?> fetchedAt() async => _database.readCache(_key)?.fetchedAt;

  /// The cache mirrors the server, so each refresh replaces it completely.
  /// It is a single Hive write, so it either fully happens or not at all.
  Future<void> replaceAll(
    List<AttendanceRecordModel> records,
    DateTime fetchedAt,
  ) {
    return _database.writeCache(
      _key,
      [for (final record in records) record.toDb()],
      fetchedAt,
    );
  }
}
