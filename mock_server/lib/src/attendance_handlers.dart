import 'package:shelf/shelf.dart';

import 'dates.dart';
import 'http_helpers.dart';
import 'models.dart';
import 'store.dart';

final _monthPattern = RegExp(r'^\d{4}-(0[1-9]|1[0-2])$');

/// GET /attendance?month=YYYY-MM
/// `month` is optional: without it every record is returned (the dashboard's
/// "latest 5" can span two months at the start of a month). Newest first.
Response getAttendance(Request request, Store store) {
  final month = request.url.queryParameters['month'];
  if (month != null && !_monthPattern.hasMatch(month)) {
    return errorResponse(400, 'INVALID_MONTH', 'month must look like 2026-11.',
        field: 'month');
  }
  final records = store.attendanceByDate.values
      .where((r) => month == null || r.workDate.startsWith(month))
      .toList()
    ..sort((a, b) => b.workDate.compareTo(a.workDate));
  return jsonResponse(200, {
    'month': month,
    'records': [for (final r in records) r.toJson()],
  });
}

/// POST /attendance/events
///
/// The server trusts nothing the app has already checked. In order:
///   1. shape of the body
///   2. idempotency  (a retry is answered with the original record)
///   3. timestamp sanity and work date
///   4. geofence
///   5. attendance rules (one check-in per day, check-out after check-in)
Future<Response> postAttendanceEvent(Request request, Store store) async {
  final body = await readJsonObject(request);
  if (body == null) return invalidJson();

  Response invalid(String field, String message) =>
      errorResponse(422, 'VALIDATION_ERROR', message, field: field);

  // ---- 1. shape -----------------------------------------------------------
  final eventId = body['event_id'];
  if (eventId is! String || eventId.trim().isEmpty) {
    return invalid('event_id', 'event_id is required.');
  }
  // The header and the body must name the same event; a mismatch is a
  // client bug and must not be guessed at.
  final headerKey = request.headers['idempotency-key'];
  if (headerKey != null && headerKey != eventId) {
    return errorResponse(400, 'IDEMPOTENCY_KEY_MISMATCH',
        'Idempotency-Key header does not match event_id.');
  }

  // ---- 2. idempotency -----------------------------------------------------
  // Checked BEFORE the business rules on purpose. If the first attempt was
  // saved but its response was lost, the retry must get the original record
  // back — not "attendance already exists", which the rules below would say.
  final alreadyProcessed = store.recordByEventId[eventId];
  if (alreadyProcessed != null) {
    return jsonResponse(200, alreadyProcessed.toJson(),
        headers: {'idempotent-replay': 'true'});
  }

  final type = body['type'];
  if (type != 'CHECK_IN' && type != 'CHECK_OUT') {
    return invalid('type', 'type must be CHECK_IN or CHECK_OUT.');
  }
  final occurredRaw = body['occurred_at'];
  final occurredAt = occurredRaw is String ? DateTime.tryParse(occurredRaw) : null;
  // isUtc is true only when the string carried a Z or an offset, so a
  // timezone-less (ambiguous) timestamp is refused.
  if (occurredAt == null || !occurredAt.isUtc) {
    return invalid('occurred_at', 'occurred_at must be a UTC ISO-8601 time.');
  }
  final workDate = body['work_date'];
  if (parseDate(workDate) == null) {
    return invalid('work_date', 'work_date must look like 2026-11-16.');
  }
  final lat = body['lat'];
  final lng = body['lng'];
  if (lat is! num || lat.abs() > 90 || lng is! num || lng.abs() > 180) {
    return invalid('lat', 'A valid location (lat, lng) is required.');
  }

  // ---- 3. timestamp sanity ------------------------------------------------
  final now = store.now().toUtc();
  if (occurredAt.isAfter(now.add(store.config.allowedClockSkew))) {
    return errorResponse(422, 'TIMESTAMP_IN_FUTURE',
        'The event time is in the future. Check the device clock.',
        field: 'occurred_at');
  }
  if (occurredAt.isBefore(now.subtract(store.config.maxEventAge))) {
    return errorResponse(
        422,
        'TIMESTAMP_TOO_OLD',
        'The event is older than ${store.config.maxEventAge.inDays} days '
            'and can no longer be recorded.',
        field: 'occurred_at');
  }
  // The server works out the working day itself, in the company timezone.
  // The client's work_date only has to agree with it.
  if (store.workDateOf(occurredAt) != workDate) {
    return errorResponse(422, 'WORK_DATE_MISMATCH',
        'work_date does not match occurred_at in the company timezone.',
        field: 'work_date');
  }

  // ---- 4. geofence --------------------------------------------------------
  final config = store.config;
  final distance = distanceInMeters(
      lat.toDouble(), lng.toDouble(), config.officeLat, config.officeLng);
  if (distance > config.officeRadiusMeters) {
    return errorResponse(
        422,
        'OUTSIDE_GEOFENCE',
        'You are ${distance.round()} m from the office. Attendance is allowed '
            'within ${config.officeRadiusMeters.round()} m.');
  }

  // ---- 5. attendance rules ------------------------------------------------
  final record = store.attendanceByDate[workDate as String];

  if (type == 'CHECK_IN') {
    if (record != null) {
      return errorResponse(409, 'ATTENDANCE_ALREADY_EXISTS',
          'A check-in already exists for $workDate.');
    }
    final created = AttendanceRecord(
      id: store.newId('att'),
      workDate: workDate,
      checkInAt: occurredAt,
      checkInEventId: eventId,
    );
    store.attendanceByDate[workDate] = created;
    store.recordByEventId[eventId] = created;
    return jsonResponse(201, created.toJson());
  }

  // CHECK_OUT. Looking the record up by work_date is also what forbids
  // overnight sessions: a check-out can only close a check-in of its own day.
  if (record == null) {
    return errorResponse(409, 'CHECK_IN_REQUIRED',
        'There is no check-in for $workDate to check out from.');
  }
  if (record.checkOutAt != null) {
    return errorResponse(409, 'ALREADY_CHECKED_OUT',
        'A check-out already exists for $workDate.');
  }
  if (!occurredAt.isAfter(record.checkInAt)) {
    return errorResponse(422, 'INVALID_ORDER',
        'Check-out must be later than the check-in.',
        field: 'occurred_at');
  }
  record.checkOutAt = occurredAt;
  record.checkOutEventId = eventId;
  store.recordByEventId[eventId] = record;
  return jsonResponse(201, record.toJson());
}
