import 'package:shelf/shelf.dart';

/// Prints each request and response with their bodies, so a reviewer can
/// watch the app talk to the server:
///
///   --> POST /attendance/events  [Idempotency-Key: 3f2b...]
///       {"event_id":"3f2b...","type":"CHECK_IN",...}
///   <-- 201 (3 ms)
///       {"id":"att_11","work_date":"2026-11-16",...}
///
/// Bodies are streams that can be read only once, so each is read into a
/// string and then put back with `change(body: ...)` for the next reader.
Middleware logRequestsWithBodies({void Function(String) log = print}) {
  return (Handler inner) {
    return (Request request) async {
      final started = DateTime.now();
      final requestBody = await request.readAsString();

      final notes = [
        if (request.headers['idempotency-key'] case final key?)
          'Idempotency-Key: $key',
        if (request.headers['x-mock-scenario'] case final name?)
          'X-Mock-Scenario: $name',
      ];
      log('--> ${request.method} /${request.url}'
          '${notes.isEmpty ? '' : '  [${notes.join(', ')}]'}');
      if (requestBody.isNotEmpty) log('    $requestBody');

      final response = await inner(request.change(body: requestBody));

      final responseBody = await response.readAsString();
      final ms = DateTime.now().difference(started).inMilliseconds;
      log('<-- ${response.statusCode} ($ms ms)');
      if (responseBody.isNotEmpty) log('    $responseBody');
      return response.change(body: responseBody);
    };
  };
}
