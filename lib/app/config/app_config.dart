/// Build-time configuration. Everything here can be overridden with
/// `--dart-define=KEY=value`, so no environment detail is hardcoded elsewhere.
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.officeLat,
    required this.officeLng,
    required this.officeRadiusMeters,
    required this.timezone,
    required this.mockLocation,
  });

  /// Reads the dart-defines. `String.fromEnvironment` only works in a const
  /// context, which is why the values are const fields below.
  static const AppConfig fromEnvironment = AppConfig(
    apiBaseUrl: _apiBaseUrl,
    officeLat: 9.9312,
    officeLng: 76.2673,
    officeRadiusMeters: 200,
    timezone: 'Asia/Kolkata',
    mockLocation: _mockLocation,
  );

  // 10.0.2.2 is how the Android emulator reaches the host machine's localhost.
  static const _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  // Empty = use the real device GPS. Otherwise one of:
  // inside | outside | denied | denied_forever | unavailable
  static const _mockLocation = String.fromEnvironment('MOCK_LOCATION');

  final String apiBaseUrl;

  /// Fallback office geofence. The server's /employee/me values win when
  /// they are available; these are only used before the first successful fetch.
  final double officeLat;
  final double officeLng;
  final double officeRadiusMeters;

  /// IANA name of the company timezone. The working-day boundary is computed
  /// in this zone, never in the device's zone.
  final String timezone;

  final String mockLocation;
}
