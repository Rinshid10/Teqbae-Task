import 'package:dio/dio.dart';

import '../error/exceptions.dart';
import '../error/failures.dart';
import '../strings/app_strings.dart';

/// Step 1 (used by remote data sources): run a Dio call and turn Dio's own
/// error type into one of our exceptions, so nothing outside the data
/// sources knows Dio exists.
Future<T> guardRequest<T>(Future<T> Function() request) async {
  try {
    return await request();
  } on DioException catch (e) {
    throw _toException(e);
  }
}

Exception _toException(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const RequestTimeoutException();

    case DioExceptionType.badResponse:
      final status = e.response?.statusCode ?? 0;
      final data = e.response?.data;
      final body = data is Map ? data : const <dynamic, dynamic>{};

      // Optional list of all field errors: [{"field": .., "message": ..}].
      final fieldErrors = <String, String>{};
      final errors = body['errors'];
      if (errors is List) {
        for (final item in errors) {
          if (item is Map && item['field'] is String && item['message'] is String) {
            // Keep the first message per field.
            fieldErrors.putIfAbsent(
                item['field'] as String, () => item['message'] as String);
          }
        }
      }
      final field = body['field'] is String ? body['field'] as String : null;
      final message = body['message'] is String
          ? body['message'] as String
          : AppStrings.requestFailed(status);
      if (field != null) fieldErrors.putIfAbsent(field, () => message);

      return ApiException(
        statusCode: status,
        code: body['code'] is String ? body['code'] as String : 'HTTP_$status',
        message: message,
        field: field,
        fieldErrors: fieldErrors,
      );

    // connectionError, badCertificate, cancel, unknown, and any type a
    // future Dio version adds: treat as "could not reach the server".
    default:
      return const NetworkException();
  }
}

/// Step 2 (used by repositories): turn anything thrown by a data source into
/// a Failure. The three retry-relevant groups are kept apart because the
/// sync engine treats them differently:
///   Network / Timeout / Server  -> keep the event, retry later
///   Rejected                    -> never retry
Failure toFailure(Object error) {
  return switch (error) {
    RequestTimeoutException() => const TimeoutFailure(AppStrings.timeout),
    NetworkException() => const NetworkFailure(AppStrings.noConnection),
    // 408 (request timeout) and 429 (rate limited) are temporary too.
    ApiException(:final statusCode, :final message)
        when statusCode >= 500 || statusCode == 408 || statusCode == 429 =>
      ServerFailure(message, statusCode: statusCode),
    ApiException e => RejectedFailure(
        e.message,
        code: e.code,
        field: e.field,
        fieldErrors: e.fieldErrors,
      ),
    CacheException() => const CacheFailure(AppStrings.cacheError),
    // e.g. a response whose JSON did not have the expected shape.
    _ => const ServerFailure(AppStrings.unexpectedResponse),
  };
}
