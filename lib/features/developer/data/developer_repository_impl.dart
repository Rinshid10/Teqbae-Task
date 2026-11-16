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

  static const _resetPath = '/__mock/reset';
  static const _officePath = '/__mock/office';

  @override
  Future<Result<void>> setOffice({
    required double lat,
    required double lng,
  }) async {
    try {
      await guardRequest(() =>
          _dio.post<dynamic>(_officePath, data: {'lat': lat, 'lng': lng}));
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
