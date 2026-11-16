import '../../../../core/database/app_database.dart';
import '../models/employee_model.dart';

/// The cached employee, kept in Hive under one key.
class EmployeeLocalDataSource {
  const EmployeeLocalDataSource(this._database);

  final AppDatabase _database;

  static const _key = AppDatabase.employeeKey;

  Future<EmployeeModel?> read() async {
    final entry = _database.readCache(_key);
    if (entry == null) return null;
    return EmployeeModel.fromDb(AppDatabase.row(entry.data));
  }

  Future<DateTime?> fetchedAt() async => _database.readCache(_key)?.fetchedAt;

  /// Replaces the cached employee (one write: data and timestamp together).
  Future<void> save(EmployeeModel employee, DateTime fetchedAt) =>
      _database.writeCache(_key, employee.toDb(), fetchedAt);
}
