import '../../domain/entities/employee.dart';

/// Employee plus the conversions the data layer needs. It extends the
/// entity, so a model can be handed to the domain as-is with no mapping step.
class EmployeeModel extends Employee {
  const EmployeeModel({
    required super.id,
    required super.name,
    required super.department,
    required super.designation,
    required super.office,
    required super.timezone,
  });

  /// From GET /employee/me. Numbers go through `num` because JSON does not
  /// distinguish 200 from 200.0.
  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    final office = json['office'] as Map<String, dynamic>;
    return EmployeeModel(
      id: json['id'] as String,
      name: json['name'] as String,
      department: json['department'] as String,
      designation: (json['designation'] as String?) ?? '',
      office: Office(
        lat: (office['lat'] as num).toDouble(),
        lng: (office['lng'] as num).toDouble(),
        radiusMeters: (office['radiusMeters'] as num).toDouble(),
      ),
      timezone: json['timezone'] as String,
    );
  }

  factory EmployeeModel.fromDb(Map<String, Object?> row) => EmployeeModel(
        id: row['id'] as String,
        name: row['name'] as String,
        department: row['department'] as String,
        designation: row['designation'] as String,
        office: Office(
          lat: row['office_lat'] as double,
          lng: row['office_lng'] as double,
          radiusMeters: row['office_radius_m'] as double,
        ),
        timezone: row['timezone'] as String,
      );

  Map<String, Object?> toDb() => {
        'id': id,
        'name': name,
        'department': department,
        'designation': designation,
        'office_lat': office.lat,
        'office_lng': office.lng,
        'office_radius_m': office.radiusMeters,
        'timezone': timezone,
      };
}
