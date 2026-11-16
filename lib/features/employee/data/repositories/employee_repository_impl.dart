import '../../../../core/network/cached_fetch.dart';
import '../../../../core/utils/cached.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/employee.dart';
import '../../domain/repositories/employee_repository.dart';
import '../datasources/employee_local_data_source.dart';
import '../datasources/employee_remote_data_source.dart';
import '../models/employee_model.dart';

class EmployeeRepositoryImpl implements EmployeeRepository {
  const EmployeeRepositoryImpl({
    required EmployeeRemoteDataSource remote,
    required EmployeeLocalDataSource local,
    required Clock clock,
  })  : _remote = remote,
        _local = local,
        _clock = clock;

  final EmployeeRemoteDataSource _remote;
  final EmployeeLocalDataSource _local;
  final Clock _clock;

  @override
  Future<Result<Cached<Employee>>> getEmployee({bool refresh = true}) {
    return cachedFetch<Employee>(
      refresh: refresh,
      clock: _clock,
      fetchRemote: _remote.fetchEmployee,
      saveCache: (employee, at) => _local.save(employee as EmployeeModel, at),
      readCache: () async {
        final employee = await _local.read();
        if (employee == null) return null;
        return Cached(employee,
            fetchedAt: await _local.fetchedAt(), isStale: true);
      },
    );
  }

  @override
  Future<Employee?> cachedEmployee() async {
    try {
      return await _local.read();
    } catch (_) {
      return null; // caller falls back to the configured office
    }
  }
}
