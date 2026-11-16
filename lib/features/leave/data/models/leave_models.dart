import '../../../../core/utils/clock.dart';
import '../../domain/entities/leave.dart';

class LeaveBalanceModel extends LeaveBalance {
  const LeaveBalanceModel({
    required super.type,
    required super.total,
    required super.used,
    required super.pending,
    required super.available,
  });

  /// The API and the cache table share column names.
  factory LeaveBalanceModel.fromMap(Map<String, Object?> map) =>
      LeaveBalanceModel(
        type: LeaveType.fromWire(map['type'] as String),
        total: map['total'] as int,
        used: map['used'] as int,
        pending: (map['pending'] as int?) ?? 0,
        available: map['available'] as int,
      );

  factory LeaveBalanceModel.fromJson(Map<String, dynamic> json) =>
      LeaveBalanceModel.fromMap(json);

  factory LeaveBalanceModel.fromDb(Map<String, Object?> row) =>
      LeaveBalanceModel.fromMap(row);

  Map<String, Object?> toDb() => {
        'type': type.wire,
        'total': total,
        'used': used,
        'pending': pending,
        'available': available,
      };
}

class LeaveRequestModel extends LeaveRequest {
  const LeaveRequestModel({
    required super.id,
    required super.type,
    required super.startDate,
    required super.endDate,
    required super.days,
    required super.reason,
    required super.status,
    required super.createdAt,
  });

  factory LeaveRequestModel.fromMap(Map<String, Object?> map) =>
      LeaveRequestModel(
        id: map['id'] as String,
        type: LeaveType.fromWire(map['type'] as String),
        startDate: _date(map['start_date'] as String),
        endDate: _date(map['end_date'] as String),
        days: map['days'] as int,
        reason: map['reason'] as String,
        status: LeaveStatus.fromWire(map['status'] as String),
        createdAt: DateTime.parse(map['created_at'] as String).toUtc(),
      );

  factory LeaveRequestModel.fromJson(Map<String, dynamic> json) =>
      LeaveRequestModel.fromMap(json);

  factory LeaveRequestModel.fromDb(Map<String, Object?> row) =>
      LeaveRequestModel.fromMap(row);

  /// "2026-11-16" -> date-only UTC midnight, the app-wide form for dates.
  static DateTime _date(String value) => Clock.dateOnly(DateTime.parse(value));

  Map<String, Object?> toDb() => {
        'id': id,
        'type': type.wire,
        'start_date': Clock.formatDate(startDate),
        'end_date': Clock.formatDate(endDate),
        'days': days,
        'reason': reason,
        'status': status.wire,
        'created_at': createdAt.toUtc().toIso8601String(),
      };
}

/// Body of POST /leave/requests.
Map<String, Object?> leaveDraftToJson(LeaveDraft draft) => {
      'type': draft.type.wire,
      'start_date':
          draft.startDate == null ? null : Clock.formatDate(draft.startDate!),
      'end_date':
          draft.endDate == null ? null : Clock.formatDate(draft.endDate!),
      'reason': draft.reason.trim(),
    };
