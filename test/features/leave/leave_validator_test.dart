import 'package:flutter_test/flutter_test.dart';
import 'package:rebs_hrms/features/leave/domain/entities/leave.dart';
import 'package:rebs_hrms/features/leave/domain/validators/leave_validator.dart';

void main() {
  const validator = LeaveValidator();
  final today = DateTime.utc(2026, 11, 16);
  DateTime day(int offset) => today.add(Duration(days: offset));

  const balances = [
    LeaveBalance(
        type: LeaveType.casual, total: 12, used: 2, pending: 2, available: 8),
    LeaveBalance(
        type: LeaveType.sick, total: 8, used: 0, pending: 0, available: 3),
  ];

  LeaveRequest existing(int from, int to, LeaveStatus status) => LeaveRequest(
        id: 'leave_$from',
        type: LeaveType.casual,
        startDate: day(from),
        endDate: day(to),
        days: to - from + 1,
        reason: 'Existing request',
        status: status,
        createdAt: today,
      );

  /// Runs the validator and returns just the codes of the broken rules.
  Set<LeaveIssueCode> check({
    int? from = 1,
    int? to = 2,
    String reason = 'Family function',
    LeaveType type = LeaveType.casual,
    List<LeaveRequest> requests = const [],
  }) {
    final issues = validator.validate(
      draft: LeaveDraft(
        type: type,
        startDate: from == null ? null : day(from),
        endDate: to == null ? null : day(to),
        reason: reason,
      ),
      today: today,
      balances: balances,
      existing: requests,
    );
    return issues.map((i) => i.code).toSet();
  }

  test('a valid request has no issues', () {
    expect(check(), isEmpty);
  });

  group('dates', () {
    test('start today is allowed; yesterday is not', () {
      expect(check(from: 0, to: 0), isEmpty);
      expect(check(from: -1, to: 0), {LeaveIssueCode.startInPast});
    });

    test('end must not be before start; a single day is fine', () {
      expect(check(from: 3, to: 2), {LeaveIssueCode.endBeforeStart});
      expect(check(from: 3, to: 3), isEmpty);
    });

    test('missing dates are reported per field', () {
      final issues = validator.validate(
        draft: const LeaveDraft(
            type: LeaveType.casual,
            startDate: null,
            endDate: null,
            reason: 'Family function'),
        today: today,
        balances: balances,
        existing: const [],
      );
      expect(issues.map((i) => i.field),
          [LeaveFields.startDate, LeaveFields.endDate]);
    });
  });

  group('reason', () {
    test('needs at least 10 non-whitespace characters', () {
      expect(check(reason: 'too short'), {LeaveIssueCode.reasonTooShort});
      expect(check(reason: '1234567890'), isEmpty);
    });

    test('spaces, tabs and newlines do not count', () {
      // 18 characters long, but only 9 of them are not whitespace.
      expect(check(reason: 'a b c d e f g h i '), {LeaveIssueCode.reasonTooShort});
      expect(check(reason: '          '), {LeaveIssueCode.reasonTooShort});
      expect(check(reason: 'abc\n\tdef\n ghi'), {LeaveIssueCode.reasonTooShort});
      // Ten real characters spread across whitespace is enough.
      expect(check(reason: 'ab cd ef gh ij'), isEmpty);
    });
  });

  group('balance', () {
    test('days are counted inclusively', () {
      expect(LeaveValidator.countDays(day(1), day(1)), 1);
      expect(LeaveValidator.countDays(day(10), day(12)), 3);
      // Across a month boundary.
      expect(
          LeaveValidator.countDays(
              DateTime.utc(2026, 11, 29), DateTime.utc(2026, 12, 2)),
          4);
    });

    test('exactly the available balance is allowed; one more is not', () {
      expect(check(from: 1, to: 3, type: LeaveType.sick), isEmpty); // 3 of 3
      expect(check(from: 1, to: 4, type: LeaveType.sick),
          {LeaveIssueCode.insufficientBalance});
    });

    test('the balance of the chosen type is the one checked', () {
      // 5 days: too many for sick (3 left), fine for casual (8 left).
      expect(check(from: 1, to: 5, type: LeaveType.sick),
          {LeaveIssueCode.insufficientBalance});
      expect(check(from: 1, to: 5, type: LeaveType.casual), isEmpty);
    });
  });

  group('overlap with an existing request on days 10..14', () {
    final pending = [existing(10, 14, LeaveStatus.pending)];

    test('inside the existing range', () {
      expect(check(from: 11, to: 12, requests: pending),
          {LeaveIssueCode.overlap});
    });

    test('touching its first day', () {
      expect(check(from: 8, to: 10, requests: pending),
          {LeaveIssueCode.overlap});
    });

    test('touching its last day', () {
      expect(check(from: 14, to: 15, requests: pending),
          {LeaveIssueCode.overlap});
    });

    test('enclosing it completely', () {
      expect(check(from: 9, to: 15, requests: pending),
          {LeaveIssueCode.overlap});
    });

    test('exactly the same range', () {
      expect(check(from: 10, to: 14, requests: pending),
          {LeaveIssueCode.overlap});
    });

    test('the day before and the day after are free', () {
      expect(check(from: 8, to: 9, requests: pending), isEmpty);
      expect(check(from: 15, to: 16, requests: pending), isEmpty);
    });

    test('APPROVED blocks too; REJECTED does not', () {
      expect(
          check(
              from: 11,
              to: 12,
              requests: [existing(10, 14, LeaveStatus.approved)]),
          {LeaveIssueCode.overlap});
      expect(
          check(
              from: 11,
              to: 12,
              requests: [existing(10, 14, LeaveStatus.rejected)]),
          isEmpty);
    });
  });

  test('all broken rules are reported together', () {
    expect(check(from: -2, to: -3, reason: 'short'), {
      LeaveIssueCode.startInPast,
      LeaveIssueCode.endBeforeStart,
      LeaveIssueCode.reasonTooShort,
    });
  });
}
