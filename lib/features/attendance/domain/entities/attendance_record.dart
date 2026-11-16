/// One day of attendance as the SERVER has it.
class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.workDate,
    required this.checkInAt,
    required this.checkOutAt,
  });

  final String id;

  /// Company working day, yyyy-MM-dd.
  final String workDate;
  final DateTime checkInAt; // UTC
  final DateTime? checkOutAt; // UTC, null while still checked in

  @override
  bool operator ==(Object other) =>
      other is AttendanceRecord &&
      other.id == id &&
      other.workDate == workDate &&
      other.checkInAt == checkInAt &&
      other.checkOutAt == checkOutAt;

  @override
  int get hashCode => Object.hash(id, workDate, checkInAt, checkOutAt);
}
