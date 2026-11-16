import '../../../../core/utils/result.dart';
import '../entities/geo_position.dart';

/// Where the device is. An interface so the app can swap the real GPS for a
/// simulated one (reviewers, tests) without the domain noticing.
abstract class LocationService {
  /// A position, or a LocationFailure whose `issue` says exactly why not
  /// (service off, permission denied, denied forever, timeout, unavailable).
  /// Asks for permission itself when it has not been decided yet.
  Future<Result<GeoPosition>> currentPosition();

  /// Opens the system screen where location (GPS) is switched on.
  Future<void> openLocationSettings();

  /// Opens this app's settings page, the only way out of "denied forever".
  Future<void> openAppSettings();
}
