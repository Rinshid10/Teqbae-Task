import '../../domain/entities/attendance_record.dart';

class AttendanceRecordModel extends AttendanceRecord {
  const AttendanceRecordModel({
    required super.id,
    required super.workDate,
    required super.checkInAt,
    required super.checkOutAt,
  });

  /// The API and the cache table use the same column names, so one parser
  /// serves both. Times are stored as UTC ISO-8601 text.
  factory AttendanceRecordModel.fromMap(Map<String, Object?> map) {
    final checkOut = map['check_out_at'] as String?;
    return AttendanceRecordModel(
      id: map['id'] as String,
      workDate: map['work_date'] as String,
      checkInAt: DateTime.parse(map['check_in_at'] as String).toUtc(),
      checkOutAt: checkOut == null ? null : DateTime.parse(checkOut).toUtc(),
    );
  }

  factory AttendanceRecordModel.fromJson(Map<String, dynamic> json) =>
      AttendanceRecordModel.fromMap(json);

  factory AttendanceRecordModel.fromDb(Map<String, Object?> row) =>
      AttendanceRecordModel.fromMap(row);

  Map<String, Object?> toDb() => {
        'id': id,
        'work_date': workDate,
        'check_in_at': checkInAt.toUtc().toIso8601String(),
        'check_out_at': checkOutAt?.toUtc().toIso8601String(),
      };
}
