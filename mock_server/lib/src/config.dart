/// Everything tunable about the mock server. Tests pass zero delays so the
/// "timeout" scenarios run instantly.
class ServerConfig {
  const ServerConfig({
    this.officeLat = 9.9312,
    this.officeLng = 76.2673,
    this.officeRadiusMeters = 200,
    this.timezoneName = 'Asia/Kolkata',
    this.utcOffset = const Duration(hours: 5, minutes: 30),
    this.maxEventAge = const Duration(days: 7),
    this.allowedClockSkew = const Duration(minutes: 2),
    this.slowDelay = const Duration(seconds: 4),
    this.timeoutDelay = const Duration(seconds: 15),
  });

  final double officeLat;
  final double officeLng;
  final double officeRadiusMeters;

  /// Sent to the app, which uses the IANA name with the `timezone` package.
  final String timezoneName;

  /// The server itself uses a fixed offset instead of a timezone database,
  /// to stay dependency-free. Correct for Asia/Kolkata, which has no
  /// daylight saving. A real backend would use proper timezone rules.
  final Duration utcOffset;

  /// Offline events may arrive late, but not later than this.
  final Duration maxEventAge;

  /// How far a phone's clock may run ahead of the server's before an event
  /// counts as "in the future".
  final Duration allowedClockSkew;

  /// `slow` scenario: under the app's 8 s receive timeout, so it succeeds.
  final Duration slowDelay;

  /// `timeout` scenarios: over the app's 8 s receive timeout, so it fails.
  final Duration timeoutDelay;
}
