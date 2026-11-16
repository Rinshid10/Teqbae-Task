/// A GPS fix.
class GeoPosition {
  const GeoPosition({required this.lat, required this.lng, this.accuracy});

  final double lat;
  final double lng;

  /// Estimated error in metres, when the platform reports it.
  final double? accuracy;

  @override
  bool operator ==(Object other) =>
      other is GeoPosition &&
      other.lat == lat &&
      other.lng == lng &&
      other.accuracy == accuracy;

  @override
  int get hashCode => Object.hash(lat, lng, accuracy);
}
