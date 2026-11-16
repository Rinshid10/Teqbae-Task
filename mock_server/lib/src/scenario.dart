/// The repeatable behaviours a reviewer can switch on. A scenario stays
/// active until it is changed, so the same failure can be reproduced as many
/// times as needed.
enum Scenario {
  /// Normal behaviour with full validation.
  success('success'),

  /// Every API call answers correctly after `slowDelay` (4 s).
  slow('slow'),

  /// Every API call hangs for `timeoutDelay` (15 s) and saves NOTHING.
  timeout('timeout'),

  /// POSTs are processed and SAVED, then the response hangs for 15 s.
  /// The client sees a timeout although the server has the record — the
  /// case idempotency exists for. GETs answer normally.
  timeoutAfterCommit('timeout_after_commit'),

  /// Every API call returns 500.
  serverError('server_error'),

  /// POST /attendance/events returns 409 ATTENDANCE_ALREADY_EXISTS.
  duplicateAttendance('duplicate_attendance'),

  /// POST /leave/requests returns 422 with field errors.
  leaveValidation('leave_validation');

  const Scenario(this.wireName);

  /// The name used in the X-Mock-Scenario header and /__mock/scenario body.
  final String wireName;

  static Scenario? parse(Object? name) {
    for (final s in values) {
      if (s.wireName == name) return s;
    }
    return null;
  }

  static String get allNames => values.map((s) => s.wireName).join(' | ');
}
