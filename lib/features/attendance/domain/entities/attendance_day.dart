import '../../../../core/error/failures.dart';
import '../../../sync/domain/entities/outbox_event.dart';

enum TodayStatus { notCheckedIn, checkedIn, checkedOut }

/// A check-in or check-out time plus whether the server has it yet.
class AttendanceMark {
  const AttendanceMark({required this.time, required this.isSynced});

  final DateTime time; // UTC
  final bool isSynced;

  @override
  bool operator ==(Object other) =>
      other is AttendanceMark && other.time == time && other.isSynced == isSynced;

  @override
  int get hashCode => Object.hash(time, isSynced);
}

/// One working day as the USER should see it: the server's record merged
/// with whatever is still in the local outbox. This is the "local today
/// state" — it is always derived, never stored separately, so it cannot
/// disagree with the outbox.
class AttendanceDay {
  const AttendanceDay({
    required this.workDate,
    required this.checkIn,
    required this.checkOut,
    this.rejected = const [],
  });

  final String workDate;
  final AttendanceMark? checkIn;
  final AttendanceMark? checkOut;

  /// Events for this day the server refused, kept so the reason can be shown.
  final List<OutboxEvent> rejected;

  TodayStatus get status {
    if (checkOut != null) return TodayStatus.checkedOut;
    if (checkIn != null) return TodayStatus.checkedIn;
    return TodayStatus.notCheckedIn;
  }

  /// Worked time for a finished day; null while the day is still open.
  Duration? get workedDuration => checkIn == null || checkOut == null
      ? null
      : checkOut!.time.difference(checkIn!.time);

  bool get hasAnything => checkIn != null || rejected.isNotEmpty;
}

/// Everything the attendance screens need, in one read.
class AttendanceOverview {
  const AttendanceOverview({
    required this.today,
    required this.history,
    required this.fetchedAt,
    required this.isStale,
    required this.refreshError,
  });

  /// True when the server records came from the cache (or there are none),
  /// i.e. a refresh is still worth doing.
  final bool isStale;

  final AttendanceDay today;

  /// Days that have any activity, newest first (today included if it has).
  final List<AttendanceDay> history;

  /// When server records were last fetched; null = never.
  final DateTime? fetchedAt;

  /// Why the last refresh failed, if it did. The overview itself still
  /// succeeds: local outbox events are always available.
  final Failure? refreshError;
}
