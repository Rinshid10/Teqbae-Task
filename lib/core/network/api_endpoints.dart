/// Server paths in one place. They are relative to AppConfig.apiBaseUrl.
abstract final class ApiEndpoints {
  static const employeeMe = '/employee/me';
  static const attendance = '/attendance';
  static const attendanceEvents = '/attendance/events';
  static const leaveBalance = '/leave/balance';
  static const leaveRequests = '/leave/requests';
}
