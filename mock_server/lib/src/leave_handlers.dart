import 'package:shelf/shelf.dart';

import 'dates.dart';
import 'http_helpers.dart';
import 'models.dart';
import 'store.dart';

/// GET /leave/balance
Response getLeaveBalance(Request request, Store store) =>
    jsonResponse(200, {'balances': store.balancesJson()});

/// GET /leave/requests — newest start date first.
Response getLeaveRequests(Request request, Store store) {
  final sorted = [...store.leaveRequests]
    ..sort((a, b) => b.startDate.compareTo(a.startDate));
  return jsonResponse(200, {
    'requests': [for (final r in sorted) r.toJson()],
  });
}

/// POST /leave/requests
///
/// Repeats every rule the app's LeaveValidator has. Unlike attendance, ALL
/// problems are collected and returned together, so a form can mark every
/// wrong field at once:
///
///   422 {"code": ..., "message": ..., "field": ...,     <- the first error
///        "errors": [{"code","message","field"}, ...]}   <- all of them
Future<Response> postLeaveRequest(Request request, Store store) async {
  final body = await readJsonObject(request);
  if (body == null) return invalidJson();

  final errors = <Map<String, Object?>>[];
  void fail(String code, String message, String field) =>
      errors.add(errorBody(code, message, field: field));

  final type = body['type'];
  final typeOk = Store.leaveTotals.containsKey(type);
  if (!typeOk) fail('INVALID_TYPE', 'Leave type must be CASUAL or SICK.', 'type');

  final start = parseDate(body['start_date']);
  final end = parseDate(body['end_date']);
  if (start == null) {
    fail('INVALID_DATE', 'Start date is required.', 'start_date');
  } else if (start.isBefore(store.today())) {
    // "Today" is the company's today, not the device's.
    fail('START_DATE_IN_PAST', 'Start date cannot be in the past.', 'start_date');
  }
  if (end == null) {
    fail('INVALID_DATE', 'End date is required.', 'end_date');
  } else if (start != null && end.isBefore(start)) {
    fail('END_BEFORE_START', 'End date cannot be before the start date.',
        'end_date');
  }

  final reason = body['reason'];
  // Count only non-whitespace characters, so ten spaces is not a reason.
  final reasonLength =
      reason is String ? reason.replaceAll(RegExp(r'\s'), '').length : 0;
  if (reasonLength < 10) {
    fail('REASON_TOO_SHORT', 'Reason must have at least 10 characters.',
        'reason');
  }

  // Overlap and balance only make sense for a valid date range.
  if (start != null && end != null && !end.isBefore(start)) {
    // Inclusive overlap: two ranges collide unless one ends before the other
    // starts. Sharing even a single day counts.
    final clash = store.leaveRequests.where((r) =>
        r.isActive && !start.isAfter(r.endDate) && !end.isBefore(r.startDate));
    if (clash.isNotEmpty) {
      final other = clash.first;
      fail(
          'LEAVE_OVERLAP',
          'These dates overlap an existing ${other.status.toLowerCase()} '
              'request (${formatDate(other.startDate)} to '
              '${formatDate(other.endDate)}).',
          'start_date');
    }
    if (typeOk) {
      final days = end.difference(start).inDays + 1;
      final available = store.availableLeave(type as String);
      if (days > available) {
        fail(
            'INSUFFICIENT_BALANCE',
            'You requested $days days but only $available '
                '${type.toLowerCase()} days are available.',
            'end_date');
      }
    }
  }

  if (errors.isNotEmpty) {
    return jsonResponse(422, {...errors.first, 'errors': errors});
  }

  final created = LeaveRequest(
    id: store.newId('leave'),
    type: type as String,
    startDate: start!,
    endDate: end!,
    reason: (reason as String).trim(),
    status: 'PENDING',
    createdAt: store.now().toUtc(),
  );
  store.leaveRequests.add(created);
  return jsonResponse(201, created.toJson());
}
