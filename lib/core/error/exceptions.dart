/// Exceptions are thrown ONLY inside the data layer (data sources).
/// Repositories catch them and return a `Failure` instead, so nothing above
/// the data layer needs try/catch.
library;

/// The server answered with a non-2xx status.
/// Body format: {"code": "...", "message": "...", "field": "optional"}.
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.field,
    this.fieldErrors = const {},
  });

  final int statusCode;
  final String code;
  final String message;
  final String? field;

  /// Parsed from the optional "errors" list: field name -> message.
  final Map<String, String> fieldErrors;

  @override
  String toString() => 'ApiException($statusCode $code: $message)';
}

/// Could not connect at all — the request never reached the server.
class NetworkException implements Exception {
  const NetworkException([this.message = 'No connection']);
  final String message;
}

/// Sent, but no answer in time. Named RequestTimeoutException so it does not
/// clash with dart:async's TimeoutException.
class RequestTimeoutException implements Exception {
  const RequestTimeoutException([this.message = 'Request timed out']);
  final String message;
}

/// Local database read/write failed.
class CacheException implements Exception {
  const CacheException([this.message = 'Local storage error']);
  final String message;
}
