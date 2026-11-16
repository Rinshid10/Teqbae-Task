import 'package:dio/dio.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/error_mapper.dart';
import '../models/employee_model.dart';

class EmployeeRemoteDataSource {
  const EmployeeRemoteDataSource(this._dio);

  final Dio _dio;

  Future<EmployeeModel> fetchEmployee() => guardRequest(() async {
        final response =
            await _dio.get<Map<String, dynamic>>(ApiEndpoints.employeeMe);
        return EmployeeModel.fromJson(response.data!);
      });
}
