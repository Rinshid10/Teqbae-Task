import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Prints every API request and its response (or error) to the debug console.
///
/// Example output in the `flutter run` console / Logcat:
///
///   [API] --> POST http://10.0.2.2:8080/attendance/events
///   [API]     Idempotency-Key: 3f2b...
///   [API]     body: {"event_id": "3f2b...", "type": "CHECK_IN"}
///   [API] <-- 201 POST http://10.0.2.2:8080/attendance/events (84 ms)
///   [API]     body: {"id": "att_12", "status": "CHECKED_IN"}
///
/// Written by hand (about 80 lines) instead of adding a logger package.
/// It is only installed in debug builds — see `createDio`.
class ApiLogInterceptor extends Interceptor {
  /// [log] is injectable so tests can capture the lines. The default,
  /// debugPrint, throttles output so Android does not drop long bodies.
  ApiLogInterceptor({void Function(String line)? log})
      : _log = log ?? ((line) => debugPrint(line));

  final void Function(String line) _log;

  static const _startedAtKey = 'api_log_started_at';
  static const _encoder = JsonEncoder.withIndent('  ');

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Remember when the request left, so the response line can show how
    // long the server took. `extra` is a per-request scratch map.
    options.extra[_startedAtKey] = DateTime.now();

    _log('[API] --> ${options.method} ${options.uri}');
    // Only the headers that matter for debugging sync are printed.
    for (final name in const ['Idempotency-Key', 'X-Mock-Scenario']) {
      final value = options.headers[name];
      if (value != null) _log('[API]     $name: $value');
    }
    if (options.data != null) _log('[API]     body: ${_pretty(options.data)}');

    handler.next(options); // pass the request on unchanged
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final request = response.requestOptions;
    _log('[API] <-- ${response.statusCode} ${request.method} ${request.uri}'
        '${_elapsed(request)}');
    _log('[API]     body: ${_pretty(response.data)}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final request = err.requestOptions;
    // A 4xx/5xx has a response; a timeout or "no connection" does not, so
    // the error type (connectionTimeout, receiveTimeout, ...) is shown instead.
    final status = err.response?.statusCode?.toString() ?? err.type.name;
    _log('[API] <-- ERROR $status ${request.method} ${request.uri}'
        '${_elapsed(request)}');
    if (err.response?.data != null) {
      _log('[API]     body: ${_pretty(err.response!.data)}');
    } else if (err.message != null) {
      _log('[API]     ${err.message}');
    }
    handler.next(err);
  }

  String _elapsed(RequestOptions request) {
    final startedAt = request.extra[_startedAtKey];
    if (startedAt is! DateTime) return '';
    return ' (${DateTime.now().difference(startedAt).inMilliseconds} ms)';
  }

  /// Maps and lists are printed as indented JSON; anything else as text.
  String _pretty(Object? data) {
    if (data is Map || data is List) {
      try {
        return _encoder.convert(data);
      } catch (_) {
        // Not JSON-encodable (e.g. FormData inside a map): fall through.
      }
    }
    return data.toString();
  }
}
