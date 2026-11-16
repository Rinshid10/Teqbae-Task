/// Route names in one place, so navigation never uses a raw string.
abstract final class AppRoutes {
  /// Launch screen; replaces itself with [shell] when its animation ends.
  static const splash = '/splash';

  /// The bottom-navigation shell hosting Home · Attendance · Leave.
  static const shell = '/';

  /// Confirmation page after a check-in or check-out.
  static const attendanceSuccess = '/attendance/success';

  /// Pending queue and sync history.
  static const syncCenter = '/sync';

  /// Leave request form, then its review step.
  static const leaveForm = '/leave/new';
  static const leaveReview = '/leave/review';

  /// Reviewer tools (debug builds).
  static const developer = '/developer';
}
