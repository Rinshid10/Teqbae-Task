import '../../../../core/strings/app_strings.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/entities/leave.dart';

/// A leave balance as finished strings, for the ring cards.
class LeaveBalanceUi {
  const LeaveBalanceUi({
    required this.type,
    required this.typeLabel,
    required this.available,
    required this.totalLabel,
    required this.fraction,
    required this.percentLabel,
  });

  final LeaveType type;
  final String typeLabel; // "Casual"
  final String available; // "6"
  final String totalLabel; // "12 days"

  /// Share of the allowance still available, 0..1 (fills the ring).
  final double fraction;
  final String percentLabel; // "50%"
}

/// A leave request as finished strings.
class LeaveRequestUi {
  const LeaveRequestUi({
    required this.typeLabel,
    required this.daysLabel,
    required this.dateRange,
    required this.reason,
    required this.statusLabel,
    required this.statusTone,
  });

  final String typeLabel; // "Casual"
  final String daysLabel; // "3 days"
  final String dateRange; // "20–22 Nov 2026"
  final String reason;
  final String statusLabel;
  final ChipTone statusTone;
}

/// The filter chips above the request list.
enum LeaveFilter { all, pending, approved, rejected }

/// The summary shown on the review step before sending.
class LeaveReviewUi {
  const LeaveReviewUi({
    required this.type,
    required this.typeLabel,
    required this.dateRange,
    required this.daysLabel,
    required this.balanceAfterLabel,
    required this.balanceNowLabel,
    required this.remainingFraction,
    required this.reason,
  });

  final LeaveType type;
  final String typeLabel; // "Casual Leave"
  final String dateRange; // "20–22 Nov 2026"
  final String daysLabel; // "3 days"
  final String? balanceAfterLabel; // "3 days remaining"
  final String? balanceNowLabel; // "(6 available now)"

  /// Share of today's balance that is left after this request, 0..1.
  final double remainingFraction;
  final String reason;
}

/// Domain -> display for leave. Used by the leave screens and the dashboard.
class LeaveUiMapper {
  const LeaveUiMapper(this._format);

  final AppFormat _format;

  static String typeLabel(LeaveType type) => switch (type) {
        LeaveType.casual => AppStrings.leaveCasual,
        LeaveType.sick => AppStrings.leaveSick,
      };

  LeaveBalanceUi balance(LeaveBalance b) {
    final fraction =
        b.total <= 0 ? 0.0 : (b.available / b.total).clamp(0.0, 1.0);
    return LeaveBalanceUi(
      type: b.type,
      typeLabel: typeLabel(b.type),
      available: '${b.available}',
      totalLabel: AppStrings.leaveDays(b.total),
      fraction: fraction,
      percentLabel: '${(fraction * 100).round()}%',
    );
  }

  LeaveRequestUi request(LeaveRequest r) => LeaveRequestUi(
        typeLabel: typeLabel(r.type),
        daysLabel: AppStrings.leaveDays(r.days),
        dateRange: _format.dateRange(r.startDate, r.endDate),
        reason: r.reason,
        statusLabel: switch (r.status) {
          LeaveStatus.pending => AppStrings.leaveStatusPending,
          LeaveStatus.approved => AppStrings.leaveStatusApproved,
          LeaveStatus.rejected => AppStrings.leaveStatusRejected,
        },
        statusTone: switch (r.status) {
          LeaveStatus.pending => ChipTone.warning,
          LeaveStatus.approved => ChipTone.success,
          LeaveStatus.rejected => ChipTone.danger,
        },
      );

  String dateRange(DateTime start, DateTime end) =>
      _format.dateRange(start, end);
}
