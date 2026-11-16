import '../../../../core/strings/app_strings.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../sync/domain/entities/outbox_event.dart';
import '../../../sync/presentation/widgets/sync_status_chip.dart';
import '../../domain/entities/attendance_day.dart';

/// A rejected event, ready to show in the "Event details" sheet.
class RejectedEventUi {
  const RejectedEventUi({
    required this.title,
    required this.typeLabel,
    required this.isCheckIn,
    required this.whenLabel,
    required this.reason,
  });

  /// "Check-in not accepted"
  final String title;

  /// "Check In"
  final String typeLabel;
  final bool isCheckIn;

  /// "15 Nov, 09:05 AM"
  final String whenLabel;
  final String reason;
}

/// One attendance day as finished strings. Views only lay these out; all
/// formatting and decisions happen in [AttendanceUiMapper].
class AttendanceDayUi {
  const AttendanceDayUi({
    required this.workDate,
    required this.dateLabel,
    required this.weekday,
    required this.dayNumber,
    required this.timeRange,
    required this.checkIn,
    required this.checkOut,
    required this.durationLabel,
    required this.metaLabel,
    required this.sync,
    required this.rejected,
  });

  final String workDate;
  final String dateLabel; // "Fri, 13 Nov"
  final String weekday; // "FRI"
  final String dayNumber; // "13"
  final String timeRange; // "09:10 - 18:15"
  final String checkIn; // "09:02 AM" or "--:--"
  final String checkOut;
  final String durationLabel; // "9h 05m", "In progress" or ""
  final String metaLabel; // "8h 53m net", "8h 47m • Stored locally"

  /// The single status shown for the day. Pending wins over rejected, which
  /// wins over synced: the row always shows the thing that needs attention.
  final SyncChipKind sync;
  final List<RejectedEventUi> rejected;
}

/// Domain -> display. Shared by the dashboard and the attendance screen so
/// a day looks the same in both places.
class AttendanceUiMapper {
  const AttendanceUiMapper(this._format);

  final AppFormat _format;

  AttendanceDayUi day(AttendanceDay day, {required bool isToday}) {
    final checkIn = day.checkIn;
    final checkOut = day.checkOut;

    final SyncChipKind sync;
    if ((checkIn != null && !checkIn.isSynced) ||
        (checkOut != null && !checkOut.isSynced)) {
      sync = SyncChipKind.pending;
    } else if (day.rejected.isNotEmpty) {
      sync = SyncChipKind.rejected;
    } else {
      sync = SyncChipKind.synced;
    }

    final worked = day.workedDuration;
    final String duration;
    if (worked != null) {
      duration = _format.duration(worked);
    } else if (checkIn != null) {
      duration =
          isToday ? AppStrings.inProgressDuration : AppStrings.noCheckOut;
    } else {
      duration = '';
    }

    final String meta = switch (sync) {
      SyncChipKind.pending => duration.isEmpty
          ? AppStrings.storedLocally
          : '$duration • ${AppStrings.storedLocally}',
      SyncChipKind.rejected => duration.isEmpty
          ? AppStrings.notAccepted
          : '$duration • ${AppStrings.notAccepted}',
      SyncChipKind.synced =>
        worked != null ? AppStrings.netDuration(duration) : duration,
    };

    return AttendanceDayUi(
      workDate: day.workDate,
      dateLabel: _format.workDate(day.workDate),
      weekday: _format.weekdayShort(day.workDate),
      dayNumber: _format.dayNumber(day.workDate),
      timeRange: _format.timeRange(checkIn?.time, checkOut?.time),
      checkIn: _format.time(checkIn?.time),
      checkOut: _format.time(checkOut?.time),
      durationLabel: duration,
      metaLabel: meta,
      sync: sync,
      rejected: day.rejected.map(rejectedEvent).toList(),
    );
  }

  RejectedEventUi rejectedEvent(OutboxEvent event) {
    final isCheckIn = event.type == AttendanceEventType.checkIn;
    return RejectedEventUi(
      title: isCheckIn
          ? AppStrings.checkInNotAccepted
          : AppStrings.checkOutNotAccepted,
      typeLabel: isCheckIn ? AppStrings.checkIn : AppStrings.checkOut,
      isCheckIn: isCheckIn,
      whenLabel: _format.dayAndTime(event.occurredAt),
      reason: (event.lastError == null || event.lastError!.isEmpty)
          ? AppStrings.noReasonGiven
          : event.lastError!,
    );
  }

  static String statusLabel(TodayStatus status) => switch (status) {
        TodayStatus.notCheckedIn => AppStrings.statusNotCheckedIn,
        TodayStatus.checkedIn => AppStrings.statusCheckedIn,
        TodayStatus.checkedOut => AppStrings.statusCheckedOut,
      };

  static ChipTone statusTone(TodayStatus status) => switch (status) {
        TodayStatus.notCheckedIn => ChipTone.neutral,
        TodayStatus.checkedIn => ChipTone.accent,
        TodayStatus.checkedOut => ChipTone.accent,
      };

  /// "Last updated 09:41 AM" — or null when the data on screen is fresh.
  String? offlineMessage({required bool refreshFailed, DateTime? fetchedAt}) {
    if (!refreshFailed) return null;
    return fetchedAt == null
        ? AppStrings.offlineBannerNoTime
        : AppStrings.offlineBanner(_format.time(fetchedAt));
  }
}
