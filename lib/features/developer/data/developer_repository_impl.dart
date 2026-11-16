import 'package:dio/dio.dart';

import '../../../core/database/app_database.dart';
import '../../../core/network/error_mapper.dart';
import '../../../core/utils/result.dart';
import '../domain/developer_repository.dart';

class DeveloperRepositoryImpl implements DeveloperRepository {
  const DeveloperRepositoryImpl({
    required Dio dio,
    required AppDatabase database,
  })  : _dio = dio,
        _database = database;

  final Dio _dio;
  final AppDatabase _database;

  static const _scenarioPath = '/__mock/scenario';
  static const _resetPath = '/__mock/reset';

  @override
  Future<Result<MockScenario>> currentScenario() async {
    try {
      final response = await guardRequest(
          () => _dio.get<Map<String, dynamic>>(_scenarioPath));
      return Success(MockScenario.fromWire(response.data?['name'] as String?));
    } catch (error) {
      return Fail(toFailure(error));
    }
  }

  @override
  Future<Result<void>> setScenario(MockScenario scenario) async {
    try {
      await guardRequest(() =>
          _dio.post<dynamic>(_scenarioPath, data: {'name': scenario.wire}));
      return const Success(null);
    } catch (error) {
      return Fail(toFailure(error));
    }
  }

  @override
  Future<Result<void>> resetServer() async {
    try {
      await guardRequest(() => _dio.post<dynamic>(_resetPath));
      return const Success(null);
    } catch (error) {
      return Fail(toFailure(error));
    }
  }

  @override
  Future<void> clearLocalData() => _database.clearAll();
}
