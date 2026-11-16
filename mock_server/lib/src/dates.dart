import 'dart:math' as math;

/// Calendar days are date-only DateTimes at UTC midnight, so comparing and
/// subtracting them is never affected by timezones or daylight saving.

final _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// `yyyy-MM-dd`.
String formatDate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

/// Strict `yyyy-MM-dd` parser. Returns null for anything else, including
/// impossible dates such as 2026-02-31 (which DateTime would silently roll
/// over into March).
DateTime? parseDate(Object? value) {
  if (value is! String || !_datePattern.hasMatch(value)) return null;
  final parts = value.split('-').map(int.parse).toList();
  final date = DateTime.utc(parts[0], parts[1], parts[2]);
  return formatDate(date) == value ? date : null;
}

/// Great-circle distance in metres (haversine). The app has the same formula
/// in core/utils/geo_utils.dart; it is repeated here because the server is a
/// separate project and must never trust the client's distance check.
double distanceInMeters(double lat1, double lng1, double lat2, double lng2) {
  const earthRadius = 6371000.0;
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}
