/// The office geofence: attendance is only allowed within [radiusMeters]
/// of this point.
class Office {
  const Office({
    required this.lat,
    required this.lng,
    required this.radiusMeters,
  });

  final double lat;
  final double lng;
  final double radiusMeters;

  @override
  bool operator ==(Object other) =>
      other is Office &&
      other.lat == lat &&
      other.lng == lng &&
      other.radiusMeters == radiusMeters;

  @override
  int get hashCode => Object.hash(lat, lng, radiusMeters);
}

class Employee {
  const Employee({
    required this.id,
    required this.name,
    required this.department,
    required this.designation,
    required this.office,
    required this.timezone,
  });

  final String id;
  final String name;
  final String department;
  final String designation;
  final Office office;

  /// IANA timezone name reported by the server (informational; the working
  /// day boundary uses AppConfig.timezone).
  final String timezone;

  @override
  bool operator ==(Object other) =>
      other is Employee &&
      other.id == id &&
      other.name == name &&
      other.department == department &&
      other.designation == designation &&
      other.office == office &&
      other.timezone == timezone;

  @override
  int get hashCode =>
      Object.hash(id, name, department, designation, office, timezone);
}
