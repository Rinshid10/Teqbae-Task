import 'dart:convert';

import 'package:shelf/shelf.dart';

const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

Response jsonResponse(
  int status,
  Object? body, {
  Map<String, String> headers = const {},
}) {
  return Response(
    status,
    body: jsonEncode(body),
    headers: {..._jsonHeaders, ...headers},
  );
}

/// Every error uses one shape, so the app needs exactly one error parser:
/// {"code": "STRING", "message": "human readable", "field": "optional"}
Map<String, Object?> errorBody(String code, String message, {String? field}) =>
    {'code': code, 'message': message, 'field': ?field};

Response errorResponse(
  int status,
  String code,
  String message, {
  String? field,
}) =>
    jsonResponse(status, errorBody(code, message, field: field));

/// Reads the body as a JSON object. Returns null when it is not one, and the
/// caller answers 400.
Future<Map<String, Object?>?> readJsonObject(Request request) async {
  try {
    final decoded = jsonDecode(await request.readAsString());
    return decoded is Map<String, Object?> ? decoded : null;
  } on FormatException {
    return null;
  }
}

Response invalidJson() => errorResponse(
      400,
      'INVALID_JSON',
      'Request body must be a JSON object.',
    );
