import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rebs_hrms/core/error/failures.dart';
import 'package:rebs_hrms/core/strings/app_strings.dart';
import 'package:rebs_hrms/core/utils/cached.dart';
import 'package:rebs_hrms/core/utils/result.dart';
import 'package:rebs_hrms/features/leave/domain/entities/leave.dart';
import 'package:rebs_hrms/features/leave/domain/repositories/leave_repository.dart';
import 'package:rebs_hrms/features/leave/domain/usecases/submit_leave_request.dart';
import 'package:rebs_hrms/features/leave/domain/validators/leave_validator.dart';

import '../../helpers/test_support.dart';

class _MockLeaveRepository extends Mock implements LeaveRepository {}

void main() {
  late _MockLeaveRepository repository;
  late FakeNetworkInfo network;
  late SubmitLeaveRequest submit;

  final clock = FakeClock.mondayMorning(); // company date: 16 Nov 2026
  final validDraft = LeaveDraft(
    type: LeaveType.casual,
    startDate: DateTime.utc(2026, 11, 20),
    endDate: DateTime.utc(2026, 11, 21),
    reason: 'Family function out of town',
  );
  final created = LeaveRequest(
    id: 'leave_9',
    type: LeaveType.casual,
    startDate: DateTime.utc(2026, 11, 20),
    endDate: DateTime.utc(2026, 11, 21),
    days: 2,
    reason: 'Family function out of town',
    status: LeaveStatus.pending,
    createdAt: clock.now,
  );

  setUpAll(() => registerFallbackValue(validDraft));

  setUp(() {
    repository = _MockLeaveRepository();
    network = FakeNetworkInfo();
    submit = SubmitLeaveRequest(
        repository: repository, networkInfo: network, clock: clock);

    when(() => repository.getBalances(refresh: false)).thenAnswer(
      (_) async => Success(Cached(const [
        LeaveBalance(
            type: LeaveType.casual, total: 12, used: 0, pending: 0, available: 12),
      ], fetchedAt: clock.now)),
    );
    when(() => repository.getRequests(refresh: false)).thenAnswer(
      (_) async => Success(Cached(const <LeaveRequest>[], fetchedAt: clock.now)),
    );
    when(() => repository.submit(any()))
        .thenAnswer((_) async => Success(created));
  });

  test('a valid request online is sent', () async {
    final result = await submit(validDraft);

    expect((result as Success<LeaveRequest>).value, created);
    verify(() => repository.submit(validDraft)).called(1);
  });

  test('offline: the exact message is shown and nothing is sent or queued',
      () async {
    network.connected = false;

    final result = await submit(validDraft);

    final failure = (result as Fail<LeaveRequest>).failure;
    expect(failure, isA<NetworkFailure>());
    expect(failure.message,
        "You're offline. Leave requests need a connection.");
    verifyNever(() => repository.submit(any()));
  });

  test('invalid input fails locally with per-field errors, before any request',
      () async {
    final result = await submit(LeaveDraft(
      type: LeaveType.casual,
      startDate: DateTime.utc(2026, 11, 15), // yesterday in company time
      endDate: DateTime.utc(2026, 11, 14),
      reason: 'short',
    ));

    final failure = (result as Fail<LeaveRequest>).failure as ValidationFailure;
    expect(failure.fieldErrors.keys, {
      LeaveFields.startDate,
      LeaveFields.endDate,
      LeaveFields.reason,
    });
    expect(failure.fieldErrors[LeaveFields.reason],
        AppStrings.leaveReasonTooShort);
    verifyNever(() => repository.submit(any()));
  });

  test('"today" is the company date, not the device or UTC date', () async {
    // 19:00 UTC on the 16th is already the 17th in the company timezone,
    // so a request starting on the 16th is in the past.
    final lateClock = FakeClock(DateTime.utc(2026, 11, 16, 19, 0));
    final lateSubmit = SubmitLeaveRequest(
        repository: repository, networkInfo: network, clock: lateClock);

    final result = await lateSubmit(LeaveDraft(
      type: LeaveType.casual,
      startDate: DateTime.utc(2026, 11, 16),
      endDate: DateTime.utc(2026, 11, 16),
      reason: 'Family function out of town',
    ));

    final failure = (result as Fail<LeaveRequest>).failure as ValidationFailure;
    expect(failure.fieldErrors.keys, {LeaveFields.startDate});
  });

  test('a server 422 comes back with its field errors intact', () async {
    when(() => repository.submit(any())).thenAnswer(
      (_) async => const Fail(RejectedFailure(
        'These dates overlap an existing request.',
        code: 'LEAVE_OVERLAP',
        field: 'start_date',
        fieldErrors: {'start_date': 'These dates overlap an existing request.'},
      )),
    );

    final result = await submit(validDraft);

    final failure = (result as Fail<LeaveRequest>).failure as RejectedFailure;
    expect(failure.fieldErrors.keys, {'start_date'});
  });

  test('losing the connection mid-request gives the offline message',
      () async {
    when(() => repository.submit(any()))
        .thenAnswer((_) async => const Fail(NetworkFailure()));

    final result = await submit(validDraft);

    expect((result as Fail<LeaveRequest>).failure.message,
        AppStrings.leaveOffline);
  });
}
