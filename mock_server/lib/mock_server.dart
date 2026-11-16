import 'dart:async';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'src/attendance_handlers.dart';
import 'src/config.dart';
import 'src/http_helpers.dart';
import 'src/leave_handlers.dart';
import 'src/scenario.dart';
import 'src/store.dart';

export 'src/config.dart';
export 'src/logging.dart';
export 'src/models.dart';
export 'src/scenario.dart';
export 'src/store.dart';

/// The whole mock API as one shelf [Handler].
///
/// bin/server.dart serves it on a port; the tests call [handler] directly
/// with Request objects, so they need no sockets and run in milliseconds.
class MockServer {
  MockServer({ServerConfig config = const ServerConfig(), DateTime Function()? now})
      : store = Store(config, now ?? DateTime.now) {
    _api = Router()
      ..get('/employee/me', _employee)
      ..get('/attendance', (Request r) => getAttendance(r, store))
      ..post('/attendance/events', (Request r) => postAttendanceEvent(r, store))
      ..get('/leave/balance', (Request r) => getLeaveBalance(r, store))
      ..get('/leave/requests', (Request r) => getLeaveRequests(r, store))
      ..post('/leave/requests', (Request r) => postLeaveRequest(r, store));

    _control = Router()
      ..get('/__mock/scenario', _getScenario)
      ..post('/__mock/scenario', _setScenario)
      ..post('/__mock/office', _setOffice)
      ..post('/__mock/reset', _reset);
  }

  final Store store;
  late final Router _api;
  late final Router _control;

  Handler get handler => _handle;

  Future<Response> _handle(Request request) async {
    // Control endpoints are never affected by scenarios; otherwise the
    // `timeout` scenario could not be switched off again.
    if (request.url.path.startsWith('__mock/')) return _control(request);

    // A per-request header wins over the global setting.
    final header = request.headers['x-mock-scenario'];
    final scenario = header == null ? store.scenario : Scenario.parse(header);
    if (scenario == null) {
      return errorResponse(400, 'UNKNOWN_SCENARIO',
          'Unknown scenario "$header". Use: ${Scenario.allNames}');
    }

    final config = store.config;
    final isPost = request.method == 'POST';
    final path = request.url.path; // no leading slash

    switch (scenario) {
      case Scenario.success:
        return _api(request);

      case Scenario.slow:
        await Future<void>.delayed(config.slowDelay);
        return _api(request);

      case Scenario.timeout:
        // Nothing is processed. By the time this answers, the app has given
        // up (8 s receive timeout) and will never see the 504.
        await Future<void>.delayed(config.timeoutDelay);
        return errorResponse(504, 'TIMEOUT', 'Simulated timeout.');

      case Scenario.timeoutAfterCommit:
        if (!isPost) return _api(request);
        // Do the real work first (the record IS saved), then stall.
        final response = await _api(request);
        await Future<void>.delayed(config.timeoutDelay);
        return response;

      case Scenario.serverError:
        return errorResponse(500, 'INTERNAL_ERROR', 'Simulated server error.');

      case Scenario.duplicateAttendance:
        if (isPost && path == 'attendance/events') {
          return errorResponse(409, 'ATTENDANCE_ALREADY_EXISTS',
              'Attendance already exists for this day.');
        }
        return _api(request);

      case Scenario.leaveValidation:
        if (isPost && path == 'leave/requests') {
          final errors = [
            errorBody('REASON_TOO_SHORT',
                'Reason must have at least 10 characters.',
                field: 'reason'),
            errorBody('LEAVE_OVERLAP',
                'These dates overlap an existing request.',
                field: 'start_date'),
          ];
          return jsonResponse(422, {...errors.first, 'errors': errors});
        }
        return _api(request);
    }
  }

  // ---- /employee/me -------------------------------------------------------

  Response _employee(Request request) {
    final c = store.config;
    return jsonResponse(200, {
      'id': 'EMP-1042',
      'name': 'Anjali Menon',
      'department': 'Engineering',
      'designation': 'Software Engineer',
      'office': {
        'lat': store.officeLat,
        'lng': store.officeLng,
        'radiusMeters': c.officeRadiusMeters,
      },
      'timezone': c.timezoneName,
    });
  }

  // ---- /__mock ------------------------------------------------------------

  Response _getScenario(Request request) =>
      jsonResponse(200, {'name': store.scenario.wireName});

  Future<Response> _setScenario(Request request) async {
    final body = await readJsonObject(request);
    final scenario = Scenario.parse(body?['name']);
    if (scenario == null) {
      return errorResponse(400, 'UNKNOWN_SCENARIO',
          'Send {"name": "..."} with one of: ${Scenario.allNames}',
          field: 'name');
    }
    store.scenario = scenario;
    return jsonResponse(200, {'name': scenario.wireName});
  }

  /// POST /__mock/office {"lat": 12.97, "lng": 77.59}
  /// Moves the office geofence, so attendance can be tested with real GPS
  /// from anywhere. The radius stays as configured. Reset undoes it.
  Future<Response> _setOffice(Request request) async {
    final body = await readJsonObject(request);
    final lat = body?['lat'];
    final lng = body?['lng'];
    if (lat is! num || lat.abs() > 90 || lng is! num || lng.abs() > 180) {
      return errorResponse(422, 'VALIDATION_ERROR',
          'Send {"lat": -90..90, "lng": -180..180}.',
          field: 'lat');
    }
    store.officeLat = lat.toDouble();
    store.officeLng = lng.toDouble();
    return jsonResponse(200, {
      'lat': store.officeLat,
      'lng': store.officeLng,
      'radiusMeters': store.config.officeRadiusMeters,
    });
  }

  Response _reset(Request request) {
    store.reset();
    return jsonResponse(200, {'reset': true, 'name': store.scenario.wireName});
  }
}
