import 'package:flutter_test/flutter_test.dart';
import 'package:rebs_hrms/core/database/app_database.dart';
import 'package:rebs_hrms/core/error/failures.dart';
import 'package:rebs_hrms/core/utils/formatters.dart';
import 'package:rebs_hrms/core/utils/result.dart';
import 'package:rebs_hrms/features/attendance/domain/usecases/check_attendance_location.dart';
import 'package:rebs_hrms/features/attendance/domain/usecases/record_attendance_event.dart';
import 'package:rebs_hrms/features/attendance/presentation/models/location_flow.dart';
import 'package:rebs_hrms/features/employee/domain/usecases/get_office.dart';
import 'package:rebs_hrms/features/sync/data/datasources/outbox_local_data_source.dart';
import 'package:rebs_hrms/features/sync/data/repositories/outbox_repository_impl.dart';
import 'package:rebs_hrms/features/sync/domain/entities/outbox_event.dart';

import '../../helpers/test_support.dart';

/// The "verify location, then confirm" flow added with the redesign.
void main() {
  late AppDatabase database;
  late OutboxRepositoryImpl outbox;
  late FakeAttendanceRepository attendance;
  late FakeLocationService location;
  late FakeClock clock;
  late CheckAttendanceLocation checkLocation;
  late RecordAttendanceEvent recordEvent;

  setUp(() async {
    database = await openTestDatabase();
    clock = FakeClock.mondayMorning();
    outbox = OutboxRepositoryImpl(
        local: OutboxLocalDataSource(database), clock: clock);
    attendance = FakeAttendanceRepository();
    location = FakeLocationService();
    final getOffice = GetOffice(FakeEmployeeRepository(), fallback: testOffice);
    checkLocation = CheckAttendanceLocation(
      attendance: attendance,
      outbox: outbox,
      location: location,
      getOffice: getOffice,
      clock: clock,
    );
    var n = 0;
    recordEvent = RecordAttendanceEvent(
      attendance: attendance,
      outbox: outbox,
      location: location,
      getOffice: getOffice,
      clock: clock,
      newEventId: () => 'evt-${++n}',
    );
  });

  tearDown(() => database.close());

  group('CheckAttendanceLocation', () {
    test('inside: reports the distance and records nothing', () async {
      final result = await checkLocation(AttendanceEventType.checkIn);

      final check = (result as Success<LocationCheck>).value;
      expect(check.isInside, isTrue);
      expect(check.distanceMeters, closeTo(5.6, 1));
      expect(await outbox.all(), isEmpty);
    });

    test('outside is a result (with the distance), not a failure', () async {
      location.result = const Success(outsideOffice);

      final result = await checkLocation(AttendanceEventType.checkIn);

      final check = (result as Success<LocationCheck>).value;
      expect(check.isInside, isFalse);
      expect(check.distanceMeters.round(), 840);
    });

    test('rules run before GPS: check-out with no check-in fails at once',
        () async {
      final result = await checkLocation(AttendanceEventType.checkOut);

      final failure = (result as Fail<LocationCheck>).failure;
      expect((failure as ValidationFailure).code, 'CHECK_IN_REQUIRED');
      expect(location.calls, 0);
    });

    test('a location failure is passed through', () async {
      location.result = const Fail(
          LocationFailure('Off', issue: LocationIssue.serviceDisabled));

      final result = await checkLocation(AttendanceEventType.checkIn);

      expect((result as Fail<LocationCheck>).failure, isA<LocationFailure>());
    });
  });

  group('RecordAttendanceEvent with a verified position', () {
    test('reuses the fix instead of asking for GPS again', () async {
      final check = (await checkLocation(AttendanceEventType.checkIn)
              as Success<LocationCheck>)
          .value;
      final callsAfterCheck = location.calls;

      final result = await recordEvent(AttendanceEventType.checkIn,
          position: check.position);

      expect(result.isSuccess, isTrue);
      expect(location.calls, callsAfterCheck);
      expect((await outbox.all()).single.lat, check.position.lat);
    });

    test('still enforces the geofence on the position it is given',
        () async {
      final result = await recordEvent(AttendanceEventType.checkIn,
          position: outsideOffice);

      final failure = (result as Fail<OutboxEvent>).failure;
      expect((failure as ValidationFailure).code, 'OUTSIDE_GEOFENCE');
      expect(await outbox.all(), isEmpty);
    });

    test('still enforces the rules: no second check-in after confirming',
        () async {
      await recordEvent(AttendanceEventType.checkIn, position: insideOffice);

      final second = await recordEvent(AttendanceEventType.checkIn,
          position: insideOffice);

      expect(((second as Fail<OutboxEvent>).failure as ValidationFailure).code,
          'ALREADY_CHECKED_IN');
    });
  });

  group('LocationFlowMapper', () {
    test('each location problem gets its own action', () {
      LocationProblemUi map(LocationIssue issue) => LocationFlowMapper.failure(
          LocationFailure('message', issue: issue));

      expect(map(LocationIssue.serviceDisabled).action,
          ProblemAction.openLocationSettings);
      expect(map(LocationIssue.denied).action, ProblemAction.retry);
      expect(map(LocationIssue.deniedForever).action,
          ProblemAction.openAppSettings);
      expect(map(LocationIssue.timeout).action, ProblemAction.retry);
      expect(map(LocationIssue.unavailable).action, ProblemAction.retry);
    });

    test('a rule failure can only be acknowledged', () {
      final problem = LocationFlowMapper.failure(
          const ValidationFailure('Already checked in', code: 'X'));
      expect(problem.kind, ProblemKind.rule);
      expect(problem.action, ProblemAction.close);
      expect(problem.body, 'Already checked in');
    });
  });

  test('ISO week numbers', () {
    expect(AppFormat.isoWeek(DateTime.utc(2026, 11, 16)), 47); // Monday
    expect(AppFormat.isoWeek(DateTime.utc(2026, 11, 15)), 46); // Sunday
    expect(AppFormat.isoWeek(DateTime.utc(2026, 1, 1)), 1); // Thursday
    // 1 Jan 2027 is a Friday, so it still belongs to week 53 of 2026.
    expect(AppFormat.isoWeek(DateTime.utc(2027, 1, 1)), 53);
  });
}
