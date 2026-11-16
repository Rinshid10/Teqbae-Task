import 'package:timezone/timezone.dart' as tz;

/// The single source of "now" for the whole app.
///
/// Why inject it instead of calling DateTime.now():
///  1. Tests can freeze time (e.g. "it is 23:59 in the company timezone").
///  2. The working-day boundary must follow the COMPANY timezone, not the
///     phone's. An employee travelling abroad still checks in on the office's
///     calendar day. Keeping that conversion here means no other file has to
///     think about timezones.
abstract class Clock {
  const Clock();

  /// The current instant, always in UTC. This is what gets stored and sent.
  DateTime nowUtc();

  /// The same instant as a wall-clock time in the company timezone.
  /// Read `.year/.month/.day/.hour/.minute` from the result for display.
  DateTime toCompanyTime(DateTime instant);

  /// Today's company working day as a date-only value (UTC midnight).
  /// Date-only values are always built with DateTime.utc so that comparing
  /// and subtracting them is never shifted by daylight-saving changes.
  DateTime today() => dateOnly(toCompanyTime(nowUtc()));

  /// The company working day an instant belongs to, as `yyyy-MM-dd`.
  String workDateOf(DateTime instant) => formatDate(toCompanyTime(instant));

  /// Strips the time part, keeping the calendar fields as they are.
  static DateTime dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  /// `yyyy-MM-dd`. Written by hand so this file needs no formatting package.
  static String formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}

/// Real clock: system time, converted with the IANA timezone database.
/// `initializeTimeZones()` must have been called once (done in main()).
class SystemClock extends Clock {
  SystemClock(String timezoneName) : _location = tz.getLocation(timezoneName);

  final tz.Location _location;

  @override
  DateTime nowUtc() => DateTime.now().toUtc();

  @override
  DateTime toCompanyTime(DateTime instant) =>
      tz.TZDateTime.from(instant, _location);
}
