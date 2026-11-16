import '../../../../core/utils/cached.dart';
import '../../../../core/utils/result.dart';
import '../entities/employee.dart';
import '../repositories/employee_repository.dart';

class GetEmployee {
  const GetEmployee(this._repository);

  final EmployeeRepository _repository;

  Future<Result<Cached<Employee>>> call({bool refresh = true}) =>
      _repository.getEmployee(refresh: refresh);
}
