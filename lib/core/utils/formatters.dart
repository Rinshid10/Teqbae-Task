import 'package:intl/intl.dart';

import 'clock.dart';

/// Turns times and dates into display text. Controllers use this so views
/// receive finished strings and do no formatting in build().
/// All clock times are shown in the COMPANY timezone.
class AppFormat {
  AppFormat(this._clock);

  final Clock _clock;

  static final _time = DateFormat('hh:mm a');
  static final _time24 = DateFormat('HH:mm');
  static final _day = DateFormat('EEE, d MMM');
  static final _dayMonth = DateFormat('d MMM');
  static final _dayWithYear = DateFormat('d MMM yyyy');
  static final _monthYear = DateFormat('MMM yyyy');
  static final _weekday = DateFormat('EEE');

  // An em dash: reads as "nothing yet" and has no odd letter spacing.
  static const noTime = '—';

  /// 09:02 AM, or a dash when there is no time yet.
  String time(DateTime? instant) =>
      instant == null ? noTime : _time.format(_clock.toCompanyTime(instant));

  /// 09:02 (24-hour), used in compact list rows.
  String time24(DateTime? instant) =>
      instant == null ? noTime : _time24.format(_clock.toCompanyTime(instant));

  /// "09:10 - 18:15", with a dash for a side that has not happened yet.
  String timeRange(DateTime? from, DateTime? to) =>
      '${time24(from)} - ${time24(to)}';

  /// "15 Nov, 09:05 AM" for an instant.
  String dayAndTime(DateTime instant) {
    final local = _clock.toCompanyTime(instant);
    return '${_dayMonth.format(local)}, ${_time.format(local)}';
  }

  /// "Mon, 16 Nov" from a date-only value.
  String day(DateTime date) => _day.format(date);

  /// "Mon, 16 Nov" from a yyyy-MM-dd work date.
  String workDate(String workDate) => _day.format(DateTime.parse(workDate));

  /// "16 Nov" from a yyyy-MM-dd work date.
  String dayMonth(String workDate) =>
      _dayMonth.format(DateTime.parse(workDate));

  /// "MON" from a yyyy-MM-dd work date.
  String weekdayShort(String workDate) =>
      _weekday.format(DateTime.parse(workDate)).toUpperCase();

  /// "09" — always two digits, so date tiles line up.
  String dayNumber(String workDate) => workDate.substring(8, 10);

  String dayWithYear(DateTime date) => _dayWithYear.format(date);

  /// "Nov 2026".
  String monthYear(DateTime month) => _monthYear.format(month);

  /// "20–22 Nov 2026", or a single date when both ends are the same day.
  String dateRange(DateTime start, DateTime end) {
    if (start == end) return _dayWithYear.format(start);
    if (start.year == end.year && start.month == end.month) {
      return '${start.day}–${_dayWithYear.format(end)}';
    }
    return '${_dayMonth.format(start)} – ${_dayWithYear.format(end)}';
  }

  /// "4h 12m" (or "12m" under an hour). Negative durations show as 0m.
  String duration(Duration d) {
    final minutes = d.isNegative ? 0 : d.inMinutes;
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h == 0 ? '${m}m' : '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  /// ISO-8601 week number of a date (weeks start on Monday; week 1 is the
  /// one containing the year's first Thursday).
  static int isoWeek(DateTime date) {
    final day = DateTime.utc(date.year, date.month, date.day);
    // Move to the Thursday of this week: its year decides the week's year.
    final thursday = day.add(Duration(days: 4 - day.weekday));
    final firstDay = DateTime.utc(thursday.year, 1, 1);
    return thursday.difference(firstDay).inDays ~/ 7 + 1;
  }
}
