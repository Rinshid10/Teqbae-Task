import 'dates.dart';

/// One working day's attendance: a check-in and, later, a check-out.
class AttendanceRecord {
  AttendanceRecord({
    required this.id,
    required this.workDate,
    required this.checkInAt,
    required this.checkInEventId,
    this.checkOutAt,
    this.checkOutEventId,
  });

  final String id;

  /// Company-local calendar day, `yyyy-MM-dd`. One record per work date.
  final String workDate;
  final DateTime checkInAt; // UTC
  DateTime? checkOutAt; // UTC

  /// The client event ids that produced this record. They are what makes
  /// POST /attendance/events idempotent.
  final String checkInEventId;
  String? checkOutEventId;

  Map<String, Object?> toJson() => {
        'id': id,
        'work_date': workDate,
        'check_in_at': checkInAt.toIso8601String(),
        'check_out_at': checkOutAt?.toIso8601String(),
        'worked_minutes': checkOutAt?.difference(checkInAt).inMinutes,
        'check_in_event_id': checkInEventId,
        'check_out_event_id': checkOutEventId,
      };
}

class LeaveRequest {
  LeaveRequest({
    required this.id,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String type; // CASUAL | SICK
  final DateTime startDate; // date-only
  final DateTime endDate; // date-only, inclusive
  final String reason;
  final String status; // PENDING | APPROVED | REJECTED
  final DateTime createdAt; // UTC

  /// Inclusive calendar days: 10th to 12th is 3 days.
  int get days => endDate.difference(startDate).inDays + 1;

  /// Rejected requests no longer block dates or hold balance.
  bool get isActive => status == 'PENDING' || status == 'APPROVED';

  Map<String, Object?> toJson() => {
        'id': id,
        'type': type,
        'start_date': formatDate(startDate),
        'end_date': formatDate(endDate),
        'days': days,
        'reason': reason,
        'status': status,
        'created_at': createdAt.toIso8601String(),
      };
}
