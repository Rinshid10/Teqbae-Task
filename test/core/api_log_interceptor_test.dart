import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebs_hrms/core/network/api_log_interceptor.dart';

/// Answers every request with a canned response, so no real server is needed.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late List<String> lines;

  Dio buildDio(int statusCode, String body) {
    lines = [];
    return Dio(BaseOptions(baseUrl: 'http://test.local'))
      ..httpClientAdapter = _FakeAdapter(statusCode, body)
      ..interceptors.add(ApiLogInterceptor(log: lines.add));
  }

  test('logs the request, idempotency key, and the response body', () async {
    final dio = buildDio(201, '{"id":"att_1","status":"CHECKED_IN"}');

    await dio.post<dynamic>(
      '/attendance/events',
      data: {'event_id': 'abc', 'type': 'CHECK_IN'},
      options: Options(headers: {'Idempotency-Key': 'abc'}),
    );

    final output = lines.join('\n');
    expect(output, contains('--> POST http://test.local/attendance/events'));
    expect(output, contains('Idempotency-Key: abc'));
    expect(output, contains('"type": "CHECK_IN"'));
    expect(output, contains('<-- 201 POST'));
    expect(output, contains('"status": "CHECKED_IN"'));
  });

  test('logs the status and error body when the server rejects', () async {
    final dio = buildDio(
      409,
      '{"code":"ATTENDANCE_ALREADY_EXISTS","message":"Already checked in"}',
    );

    await expectLater(
      dio.get<dynamic>('/attendance'),
      throwsA(isA<DioException>()),
    );

    final output = lines.join('\n');
    expect(output, contains('<-- ERROR 409 GET http://test.local/attendance'));
    expect(output, contains('ATTENDANCE_ALREADY_EXISTS'));
  });
}
