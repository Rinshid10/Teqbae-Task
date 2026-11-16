import '../entities/employee.dart';
import '../repositories/employee_repository.dart';

/// The geofence to check against: the office the server sent with
/// /employee/me if we have ever fetched it, otherwise the one in AppConfig.
/// Never touches the network, so check-in works on a first launch offline.
class GetOffice {
  const GetOffice(this._repository, {required Office fallback})
      : _fallback = fallback;

  final EmployeeRepository _repository;
  final Office _fallback;

  Future<Office> call() async {
    final employee = await _repository.cachedEmployee();
    return employee?.office ?? _fallback;
  }
}
