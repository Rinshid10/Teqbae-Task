import 'package:dio/dio.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/error_mapper.dart';
import '../../domain/entities/leave.dart';
import '../models/leave_models.dart';

class LeaveRemoteDataSource {
  const LeaveRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<LeaveBalanceModel>> fetchBalances() => guardRequest(() async {
        final response =
            await _dio.get<Map<String, dynamic>>(ApiEndpoints.leaveBalance);
        final items = response.data!['balances'] as List<dynamic>;
        return [
          for (final item in items)
            LeaveBalanceModel.fromJson(item as Map<String, dynamic>),
        ];
      });

  Future<List<LeaveRequestModel>> fetchRequests() => guardRequest(() async {
        final response =
            await _dio.get<Map<String, dynamic>>(ApiEndpoints.leaveRequests);
        final items = response.data!['requests'] as List<dynamic>;
        return [
          for (final item in items)
            LeaveRequestModel.fromJson(item as Map<String, dynamic>),
        ];
      });

  Future<LeaveRequestModel> submit(LeaveDraft draft) => guardRequest(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          ApiEndpoints.leaveRequests,
          data: leaveDraftToJson(draft),
        );
        return LeaveRequestModel.fromJson(response.data!);
      });
}
