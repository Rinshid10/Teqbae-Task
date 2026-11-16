import 'dart:convert';

import 'package:rebs_mock_server/mock_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// A decoded response: status code plus JSON body.
typedef Reply = ({int status, Map<String, dynamic> json, Map<String, String> headers});

void main() {
  // Monday 16 Nov 2026, 11:30 in the company timezone (06:00 UTC).
  final now = DateTime.utc(2026, 11, 16, 6, 0);
  const today = '2026-11-16';

  late MockServer server;

  /// Calls the handler directly — no sockets involved.
  Future<Reply> call(
    String method,
    String path, {
    Map<String, Object?>? body,
    Map<String, String> headers = const {},
  }) async {
    final response = await server.handler(Request(
      method,
      Uri.parse('http://localhost$path'),
      body: body == null ? null : jsonEncode(body),
      headers: headers,
    ));
    return (
      status: response.statusCode,
      json: jsonDecode(await response.readAsString()) as Map<String, dynamic>,
      headers: response.headers,
    );
  }

  /// A valid attendance event at the office door; tests override one field.
  Map<String, Object?> event({
    String id = 'evt-1',
    String type = 'CHECK_IN',
    DateTime? at,
    String workDate = today,
    double lat = 9.9312,
    double lng = 76.2673,
  }) =>
      {
        'event_id': id,
        'type': type,
        'occurred_at':
            (at ?? now.subtract(const Duration(hours: 2))).toIso8601String(),
        'work_date': workDate,
        'lat': lat,
        'lng': lng,
        'accuracy': 12.0,
      };

  Future<Reply> postEvent(Map<String, Object?> body,
          {Map<String, String> headers = const {}}) =>
      call('POST', '/attendance/events', body: body, headers: headers);

  /// yyyy-MM-dd for today + [offset] days.
  String day(int offset) => DateTime.utc(2026, 11, 16 + offset)
      .toIso8601String()
      .substring(0, 10);

  Map<String, Object?> leave(int from, int to,
          {String type = 'SICK', String reason = 'Recovering from a fever'}) =>
      {
        'type': type,
        'start_date': day(from),
        'end_date': day(to),
        'reason': reason,
      };

  Future<Reply> postLeave(Map<String, Object?> body) =>
      call('POST', '/leave/requests', body: body);

  setUp(() {
    server = MockServer(
      now: () => now,
      // Zero delays: the timeout scenarios keep their behaviour, not their wait.
      config: const ServerConfig(
          slowDelay: Duration.zero, timeoutDelay: Duration.zero),
    );
  });

  group('read endpoints', () {
    test('GET /employee/me returns employee, office geofence and timezone',
        () async {
      final r = await call('GET', '/employee/me');
      expect(r.status, 200);
      expect(r.json['id'], 'EMP-1042');
      expect(r.json['office'],
          {'lat': 9.9312, 'lng': 76.2673, 'radiusMeters': 200});
      expect(r.json['timezone'], 'Asia/Kolkata');
    });

    test('GET /attendance is seeded with 10 past weekdays, newest first',
        () async {
      final r = await call('GET', '/attendance');
      final records = r.json['records'] as List;
      expect(records, hasLength(10));
      // Today is a Monday, so the newest seeded day is the Friday before.
      expect(records.first['work_date'], '2026-11-13');
      expect(records.any((x) => x['work_date'] == today), isFalse);
    });

    test('GET /attendance?month filters, and rejects a malformed month',
        () async {
      final nov = await call('GET', '/attendance?month=2026-11');
      final all = nov.json['records'] as List;
      expect(all, isNotEmpty);
      expect(all.every((x) => (x['work_date'] as String).startsWith('2026-11')),
          isTrue);

      final bad = await call('GET', '/attendance?month=11-2026');
      expect(bad.status, 400);
      expect(bad.json['code'], 'INVALID_MONTH');
    });

    test('GET /leave/balance and /leave/requests reflect the seed', () async {
      final balance = await call('GET', '/leave/balance');
      final casual = (balance.json['balances'] as List)
          .firstWhere((b) => b['type'] == 'CASUAL');
      // 12 total - 2 approved - 2 pending.
      expect(casual, containsPair('available', 8));

      final requests = await call('GET', '/leave/requests');
      expect(requests.json['requests'], hasLength(3));
    });
  });

  group('POST /attendance/events', () {
    test('check-in then check-out succeeds', () async {
      final checkIn = await postEvent(event());
      expect(checkIn.status, 201);
      expect(checkIn.json['work_date'], today);
      expect(checkIn.json['check_out_at'], isNull);

      final checkOut = await postEvent(event(
          id: 'evt-2',
          type: 'CHECK_OUT',
          at: now.subtract(const Duration(minutes: 5))));
      expect(checkOut.status, 201);
      expect(checkOut.json['id'], checkIn.json['id']);
      expect(checkOut.json['worked_minutes'], 115);
    });

    test('the same event_id sent twice creates exactly one record', () async {
      final first = await postEvent(event(),
          headers: {'Idempotency-Key': 'evt-1'});
      final retry = await postEvent(event(),
          headers: {'Idempotency-Key': 'evt-1'});

      expect(first.status, 201);
      expect(retry.status, 200);
      expect(retry.headers['idempotent-replay'], 'true');
      expect(retry.json['id'], first.json['id']);

      final list = await call('GET', '/attendance');
      final todays =
          (list.json['records'] as List).where((x) => x['work_date'] == today);
      expect(todays, hasLength(1));
      expect(server.store.attendanceByDate, hasLength(11)); // 10 seeded + 1
    });

    test('a second check-in with a DIFFERENT event_id is a 409', () async {
      await postEvent(event());
      final second = await postEvent(event(id: 'evt-other'));
      expect(second.status, 409);
      expect(second.json['code'], 'ATTENDANCE_ALREADY_EXISTS');
    });

    test('check-out without a check-in is rejected', () async {
      final r = await postEvent(event(type: 'CHECK_OUT'));
      expect(r.status, 409);
      expect(r.json['code'], 'CHECK_IN_REQUIRED');
    });

    test('check-out must be later than the check-in', () async {
      await postEvent(event());
      final r = await postEvent(event(
          id: 'evt-2',
          type: 'CHECK_OUT',
          at: now.subtract(const Duration(hours: 3))));
      expect(r.status, 422);
      expect(r.json['code'], 'INVALID_ORDER');
    });

    test('a second check-out is rejected', () async {
      await postEvent(event());
      await postEvent(event(
          id: 'evt-2',
          type: 'CHECK_OUT',
          at: now.subtract(const Duration(hours: 1))));
      final r = await postEvent(event(id: 'evt-3', type: 'CHECK_OUT', at: now));
      expect(r.status, 409);
      expect(r.json['code'], 'ALREADY_CHECKED_OUT');
    });

    test('outside the geofence is rejected with the distance', () async {
      // ~0.0075 degrees of latitude is about 834 m north of the office.
      final r = await postEvent(event(lat: 9.9387));
      expect(r.status, 422);
      expect(r.json['code'], 'OUTSIDE_GEOFENCE');
      expect(r.json['message'], contains('within 200 m'));
    });

    test('a timestamp in the future is rejected', () async {
      final r = await postEvent(
          event(at: now.add(const Duration(minutes: 10))));
      expect(r.status, 422);
      expect(r.json['code'], 'TIMESTAMP_IN_FUTURE');
    });

    test('a timestamp older than 7 days is rejected', () async {
      final old = now.subtract(const Duration(days: 8));
      final r = await postEvent(event(at: old, workDate: '2026-11-08'));
      expect(r.status, 422);
      expect(r.json['code'], 'TIMESTAMP_TOO_OLD');
    });

    test('work_date must match occurred_at in the COMPANY timezone', () async {
      // 19:00 UTC on the 15th is already 00:30 on the 16th in India.
      final at = DateTime.utc(2026, 11, 15, 19, 0);
      final wrong = await postEvent(event(at: at, workDate: '2026-11-15'));
      expect(wrong.status, 422);
      expect(wrong.json['code'], 'WORK_DATE_MISMATCH');

      final right = await postEvent(event(at: at, workDate: today));
      expect(right.status, 201);
    });

    test('Idempotency-Key header must match event_id', () async {
      final r = await postEvent(event(),
          headers: {'Idempotency-Key': 'something-else'});
      expect(r.status, 400);
      expect(r.json['code'], 'IDEMPOTENCY_KEY_MISMATCH');
    });

    test('malformed bodies are rejected with the field name', () async {
      final r = await postEvent(event()..['type'] = 'LUNCH');
      expect(r.status, 422);
      expect(r.json['field'], 'type');

      final noZone = await postEvent(
          event()..['occurred_at'] = '2026-11-16T09:00:00');
      expect(noZone.json['field'], 'occurred_at');
    });
  });

  group('POST /leave/requests', () {
    test('a valid request is created as PENDING and holds balance', () async {
      final r = await postLeave(leave(20, 22));
      expect(r.status, 201);
      expect(r.json['status'], 'PENDING');
      expect(r.json['days'], 3);

      final balance = await call('GET', '/leave/balance');
      final sick = (balance.json['balances'] as List)
          .firstWhere((b) => b['type'] == 'SICK');
      expect(sick, containsPair('available', 5)); // 8 - 3
    });

    test('start date in the past is rejected', () async {
      final r = await postLeave(leave(-1, 1));
      expect(r.status, 422);
      expect(r.json['code'], 'START_DATE_IN_PAST');
      expect(r.json['field'], 'start_date');
    });

    test('end before start is rejected', () async {
      final r = await postLeave(leave(22, 20));
      expect(r.status, 422);
      expect(r.json['code'], 'END_BEFORE_START');
      expect(r.json['field'], 'end_date');
    });

    test('reason needs 10 NON-whitespace characters', () async {
      final spaces = await postLeave(leave(20, 20, reason: '   a  b  c       '));
      expect(spaces.status, 422);
      expect(spaces.json['code'], 'REASON_TOO_SHORT');

      final exactlyTen = await postLeave(leave(20, 20, reason: 'ab cd ef gh ij'));
      expect(exactlyTen.status, 201);
    });

    test('more days than the available balance is rejected', () async {
      final r = await postLeave(leave(40, 48)); // 9 days, 8 sick available
      expect(r.status, 422);
      expect(r.json['code'], 'INSUFFICIENT_BALANCE');
    });

    test('overlap is rejected: inside, edge-touching and enclosing', () async {
      expect((await postLeave(leave(20, 24))).status, 201);

      Future<void> expectOverlap(int from, int to) async {
        final r = await postLeave(leave(from, to, type: 'CASUAL'));
        expect(r.status, 422, reason: '$from..$to should overlap 20..24');
        expect(r.json['code'], 'LEAVE_OVERLAP');
        expect(r.json['field'], 'start_date');
      }

      await expectOverlap(21, 22); // inside
      await expectOverlap(24, 25); // touches the last day
      await expectOverlap(19, 20); // touches the first day
      await expectOverlap(19, 25); // encloses

      // The day after the range ends is free.
      expect((await postLeave(leave(25, 25, type: 'CASUAL'))).status, 201);
    });

    test('a REJECTED request does not block its dates', () async {
      // The seeded rejected request is in the past, so add a future one.
      server.store.leaveRequests.add(LeaveRequest(
        id: 'leave_rejected',
        type: 'SICK',
        startDate: DateTime.utc(2026, 11, 21),
        endDate: DateTime.utc(2026, 11, 21),
        reason: 'Rejected earlier',
        status: 'REJECTED',
        createdAt: now,
      ));
      final r = await postLeave(leave(5, 5)); // the same day, 21 Nov
      expect(r.status, 201);
    });

    test('all field errors are returned together', () async {
      final r = await postLeave(leave(-2, -3, reason: 'short'));
      final fields = (r.json['errors'] as List).map((e) => e['field']).toSet();
      expect(fields, {'start_date', 'end_date', 'reason'});
    });
  });

  group('scenarios', () {
    test('server_error via header affects only that request', () async {
      final failing = await call('GET', '/employee/me',
          headers: {'X-Mock-Scenario': 'server_error'});
      expect(failing.status, 500);
      expect(failing.json['code'], 'INTERNAL_ERROR');

      expect((await call('GET', '/employee/me')).status, 200);
    });

    test('POST /__mock/scenario switches globally and is repeatable',
        () async {
      final set = await call('POST', '/__mock/scenario',
          body: {'name': 'server_error'});
      expect(set.status, 200);

      // Stays active across requests until changed.
      expect((await call('GET', '/leave/balance')).status, 500);
      expect((await call('GET', '/leave/balance')).status, 500);

      // Control endpoints still work while the scenario is active.
      await call('POST', '/__mock/scenario', body: {'name': 'success'});
      expect((await call('GET', '/leave/balance')).status, 200);
    });

    test('unknown scenario names are refused', () async {
      final viaBody =
          await call('POST', '/__mock/scenario', body: {'name': 'nope'});
      expect(viaBody.status, 400);

      final viaHeader = await call('GET', '/employee/me',
          headers: {'X-Mock-Scenario': 'nope'});
      expect(viaHeader.status, 400);
      expect(viaHeader.json['code'], 'UNKNOWN_SCENARIO');
    });

    test('duplicate_attendance returns 409 and saves nothing', () async {
      final r = await postEvent(event(),
          headers: {'X-Mock-Scenario': 'duplicate_attendance'});
      expect(r.status, 409);
      expect(r.json['code'], 'ATTENDANCE_ALREADY_EXISTS');
      expect(server.store.attendanceByDate.containsKey(today), isFalse);
    });

    test('leave_validation returns 422 with field errors', () async {
      final r = await call('POST', '/leave/requests',
          body: leave(20, 21),
          headers: {'X-Mock-Scenario': 'leave_validation'});
      expect(r.status, 422);
      expect(r.json['field'], 'reason');
      expect(r.json['errors'], hasLength(2));
    });

    test('timeout saves nothing', () async {
      final r =
          await postEvent(event(), headers: {'X-Mock-Scenario': 'timeout'});
      expect(r.status, 504);
      expect(server.store.attendanceByDate.containsKey(today), isFalse);
    });

    test(
        'timeout_after_commit saves the record, and the retry with the same '
        'event_id gets that record back instead of a duplicate', () async {
      final first = await postEvent(event(),
          headers: {'X-Mock-Scenario': 'timeout_after_commit'});
      expect(server.store.attendanceByDate.containsKey(today), isTrue);

      final retry = await postEvent(event());
      expect(retry.status, 200);
      expect(retry.json['id'], first.json['id']);
      expect(server.store.attendanceByDate, hasLength(11));
    });

    test('slow still succeeds', () async {
      final r = await call('GET', '/employee/me',
          headers: {'X-Mock-Scenario': 'slow'});
      expect(r.status, 200);
    });

    test('POST /__mock/reset restores the seed and the success scenario',
        () async {
      await postEvent(event());
      await call('POST', '/__mock/scenario', body: {'name': 'server_error'});

      final reset = await call('POST', '/__mock/reset');
      expect(reset.status, 200);
      expect(server.store.attendanceByDate, hasLength(10));
      expect(server.store.scenario, Scenario.success);
      expect((await call('GET', '/attendance')).status, 200);
    });
  });
}
