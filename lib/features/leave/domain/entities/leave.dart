enum LeaveType {
  casual('CASUAL'),
  sick('SICK');

  const LeaveType(this.wire);

  /// Value used by the API and the local cache.
  final String wire;

  static LeaveType fromWire(String value) =>
      values.firstWhere((t) => t.wire == value);
}

enum LeaveStatus {
  pending('PENDING'),
  approved('APPROVED'),
  rejected('REJECTED');

  const LeaveStatus(this.wire);
  final String wire;

  static LeaveStatus fromWire(String value) =>
      values.firstWhere((s) => s.wire == value);
}

class LeaveBalance {
  const LeaveBalance({
    required this.type,
    required this.total,
    required this.used,
    required this.pending,
    required this.available,
  });

  final LeaveType type;
  final int total;
  final int used;
  final int pending;

  /// Days that can still be requested (total - used - pending).
  final int available;

  @override
  bool operator ==(Object other) =>
      other is LeaveBalance &&
      other.type == type &&
      other.total == total &&
      other.used == used &&
      other.pending == pending &&
      other.available == available;

  @override
  int get hashCode => Object.hash(type, total, used, pending, available);
}

class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final LeaveType type;

  /// Date-only values (UTC midnight). [endDate] is inclusive.
  final DateTime startDate;
  final DateTime endDate;
  final int days;
  final String reason;
  final LeaveStatus status;
  final DateTime createdAt;

  /// Pending and approved requests block their dates; rejected ones do not.
  bool get blocksDates => status != LeaveStatus.rejected;

  @override
  bool operator ==(Object other) =>
      other is LeaveRequest &&
      other.id == id &&
      other.type == type &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.days == days &&
      other.reason == reason &&
      other.status == status &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
      id, type, startDate, endDate, days, reason, status, createdAt);
}

/// What the user has typed into the leave form, not yet validated.
class LeaveDraft {
  const LeaveDraft({
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.reason,
  });

  final LeaveType type;
  final DateTime? startDate;
  final DateTime? endDate;
  final String reason;

  @override
  bool operator ==(Object other) =>
      other is LeaveDraft &&
      other.type == type &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(type, startDate, endDate, reason);
}

/// Balances and requests together, as the leave screen shows them.
class LeaveOverview {
  const LeaveOverview({required this.balances, required this.requests});

  final List<LeaveBalance> balances;
  final List<LeaveRequest> requests;
}
