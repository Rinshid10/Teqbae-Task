import '../../../../core/utils/cached.dart';
import '../../../../core/utils/result.dart';
import '../entities/employee.dart';

abstract class EmployeeRepository {
  /// See `cachedFetch` for what [refresh] means.
  Future<Result<Cached<Employee>>> getEmployee({bool refresh = true});

  /// Local-only read that never touches the network. Check-in uses it to get
  /// the office geofence without waiting on a request while offline.
  Future<Employee?> cachedEmployee();
}
