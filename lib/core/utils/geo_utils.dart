import 'dart:math' as math;

/// Great-circle distance in metres between two lat/lng points (haversine).
///
/// Written by hand rather than using Geolocator.distanceBetween so the
/// geofence rule stays pure Dart: the domain layer and the mock server can
/// both use the same formula, and it is unit-testable without a plugin.
double distanceInMeters(double lat1, double lng1, double lat2, double lng2) {
  const earthRadius = 6371000.0; // mean radius, metres
  final dLat = _toRadians(lat2 - lat1);
  final dLng = _toRadians(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(_toRadians(lat1)) *
          math.cos(_toRadians(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _toRadians(double degrees) => degrees * math.pi / 180;
