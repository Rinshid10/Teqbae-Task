import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_log_interceptor.dart';

/// Builds the one Dio instance the whole app shares.
///
/// [enableLogs] defaults to debug builds only, so a release APK never prints
/// request or response bodies.
Dio createDio({required String baseUrl, bool enableLogs = kDebugMode}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      // Short timeouts: on a bad connection we would rather fail fast, keep
      // the event in the outbox and retry, than leave the user waiting.
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 8),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  );
  if (enableLogs) dio.interceptors.add(ApiLogInterceptor());
  return dio;
}
