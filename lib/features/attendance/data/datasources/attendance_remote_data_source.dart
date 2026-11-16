import 'package:dio/dio.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/error_mapper.dart';
import '../../../sync/data/models/outbox_event_model.dart';
import '../models/attendance_record_model.dart';

class AttendanceRemoteDataSource {
  const AttendanceRemoteDataSource(this._dio);

  final Dio _dio;

  /// All records, newest first. `month` is left out on purpose: the
  /// dashboard's "latest 5" can span two months.
  Future<List<AttendanceRecordModel>> fetchRecords() => guardRequest(() async {
        final response =
            await _dio.get<Map<String, dynamic>>(ApiEndpoints.attendance);
        final records = response.data!['records'] as List<dynamic>;
        return [
          for (final item in records)
            AttendanceRecordModel.fromJson(item as Map<String, dynamic>),
        ];
      });

  /// Sends one event. The event id travels twice — as the Idempotency-Key
  /// header and in the body — and is the same on every retry, which is what
  /// lets the server recognise a repeat. Returns the server's record JSON.
  Future<Map<String, dynamic>> postEvent(OutboxEventModel event) =>
      guardRequest(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          ApiEndpoints.attendanceEvents,
          data: event.toJson(),
          options: Options(headers: {'Idempotency-Key': event.eventId}),
        );
        return response.data ?? const {};
      });
}
