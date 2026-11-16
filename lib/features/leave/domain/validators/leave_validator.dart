import '../../../../core/strings/app_strings.dart';
import '../entities/leave.dart';

/// Form field names. They match the server's `field` values, so a local
/// error and a server error for the same field land in the same place.
abstract final class LeaveFields {
  static const type = 'type';
  static const startDate = 'start_date';
  static const endDate = 'end_date';
  static const reason = 'reason';
}

/// Which rule was broken. Tests assert on this rather than on wording.
enum LeaveIssueCode {
  startRequired,
  startInPast,
  endRequired,
  endBeforeStart,
  reasonTooShort,
  overlap,
  insufficientBalance,
}

class LeaveIssue {
  const LeaveIssue(this.code, this.field, this.message);

  final LeaveIssueCode code;
  final String field;
  final String message;

  @override
  String toString() => 'LeaveIssue(${code.name} on $field)';
}

/// The leave rules. Pure Dart: everything it needs is passed in.
/// The server repeats all of these; this copy exists to give instant,
/// per-field feedback and to avoid pointless requests.
class LeaveValidator {
  const LeaveValidator();

  static const minReasonLength = 10;

  /// Inclusive calendar days: the 10th to the 12th is 3 days.
  /// Safe to compute with difference() because dates are UTC midnights.
  static int countDays(DateTime start, DateTime end) =>
      end.difference(start).inDays + 1;

  /// Letters, digits and punctuation only — spaces, tabs and newlines do
  /// not count towards the minimum.
  static int meaningfulLength(String reason) =>
      reason.replaceAll(RegExp(r'\s'), '').length;

  /// Returns every broken rule (empty list = valid), so the form can mark
  /// all fields at once.
  ///
  /// [today] is the company's current date, not the device's.
  List<LeaveIssue> validate({
    required LeaveDraft draft,
    required DateTime today,
    required List<LeaveBalance> balances,
    required List<LeaveRequest> existing,
  }) {
    final issues = <LeaveIssue>[];
    final start = draft.startDate;
    final end = draft.endDate;

    if (start == null) {
      issues.add(const LeaveIssue(LeaveIssueCode.startRequired,
          LeaveFields.startDate, AppStrings.leaveStartRequired));
    } else if (start.isBefore(today)) {
      issues.add(const LeaveIssue(LeaveIssueCode.startInPast,
          LeaveFields.startDate, AppStrings.leaveStartInPast));
    }

    if (end == null) {
      issues.add(const LeaveIssue(LeaveIssueCode.endRequired,
          LeaveFields.endDate, AppStrings.leaveEndRequired));
    } else if (start != null && end.isBefore(start)) {
      issues.add(const LeaveIssue(LeaveIssueCode.endBeforeStart,
          LeaveFields.endDate, AppStrings.leaveEndBeforeStart));
    }

    if (meaningfulLength(draft.reason) < minReasonLength) {
      issues.add(const LeaveIssue(LeaveIssueCode.reasonTooShort,
          LeaveFields.reason, AppStrings.leaveReasonTooShort));
    }

    // Overlap and balance only make sense once the range itself is valid.
    if (start != null && end != null && !end.isBefore(start)) {
      // Two inclusive ranges overlap unless one ends before the other
      // starts. Sharing a single day (edge-touching) counts as overlap.
      final clashes = existing.where((r) =>
          r.blocksDates &&
          !start.isAfter(r.endDate) &&
          !end.isBefore(r.startDate));
      if (clashes.isNotEmpty) {
        issues.add(const LeaveIssue(LeaveIssueCode.overlap,
            LeaveFields.startDate, AppStrings.leaveOverlap));
      }

      final days = countDays(start, end);
      final balance = balances.where((b) => b.type == draft.type).firstOrNull;
      // If the balance is unknown (never fetched) the check is skipped
      // here; the server still enforces it.
      if (balance != null && days > balance.available) {
        issues.add(LeaveIssue(
          LeaveIssueCode.insufficientBalance,
          LeaveFields.endDate,
          AppStrings.leaveInsufficientBalance(days, balance.available),
        ));
      }
    }

    return issues;
  }
}
