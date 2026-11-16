import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rebs_hrms/core/database/app_database.dart';
import 'package:rebs_hrms/core/error/failures.dart';
import 'package:rebs_hrms/core/utils/result.dart';
import 'package:rebs_hrms/features/attendance/domain/usecases/record_attendance_event.dart';
import 'package:rebs_hrms/features/employee/domain/usecases/get_office.dart';
import 'package:rebs_hrms/features/sync/data/datasources/outbox_local_data_source.dart';
import 'package:rebs_hrms/features/sync/data/repositories/outbox_repository_impl.dart';
import 'package:rebs_hrms/features/sync/domain/entities/outbox_event.dart';

import '../../helpers/test_support.dart';

/// The use case runs against the REAL Hive outbox (in a temp folder), so these tests
/// also exercise the outbox's own duplicate check.
void main() {
  late AppDatabase database;
  late OutboxRepositoryImpl outbox;
  late FakeAttendanceRepository attendance;
  late FakeLocationService location;
  late FakeClock clock;
  late RecordAttendanceEvent recordEvent;
  var nextId = 0;

  setUp(() async {
    database = await openTestDatabase();
    clock = FakeClock.mondayMorning();
    outbox = OutboxRepositoryImpl(
        local: OutboxLocalDataSource(database), clock: clock);
    attendance = FakeAttendanceRepository();
    location = FakeLocationService();
    nextId = 0;
    recordEvent = RecordAttendanceEvent(
      attendance: attendance,
      outbox: outbox,
      location: location,
      getOffice: GetOffice(FakeEmployeeRepository(), fallback: testOffice),
      clock: clock,
      newEventId: () => 'evt-${++nextId}',
    );
  });

  tearDown(() => database.close());

  Failure failureOf(Result<OutboxEvent> result) =>
      (result as Fail<OutboxEvent>).failure;

  test('check-in is written to the outbox as PENDING with time and GPS',
      () async {
    final result = await recordEvent(AttendanceEventType.checkIn);

    final event = (result as Success<OutboxEvent>).value;
    expect(event.status, SyncStatus.pending);
    expect(event.eventId, 'evt-1');
    expect(event.occurredAt, clock.now);
    expect(event.occurredAt.isUtc, isTrue);
    expect(event.workDate, '2026-11-16');
    expect(event.lat, insideOffice.lat);
    expect(event.lng, insideOffice.lng);
    expect(event.accuracy, insideOffice.accuracy);
    expect(await outbox.unsentCount(), 1);
  });

  test('check-out without a check-in is rejected and nothing is queued',
      () async {
    final result = await recordEvent(AttendanceEventType.checkOut);

    final failure = failureOf(result);
    expect(failure, isA<ValidationFailure>());
    expect((failure as ValidationFailure).code, 'CHECK_IN_REQUIRED');
    expect(await outbox.all(), isEmpty);
    // The rule fails before the GPS is even asked.
    expect(location.calls, 0);
  });

  test('a second check-in is blocked while the first is still PENDING',
      () async {
    await recordEvent(AttendanceEventType.checkIn);
    clock.advance(const Duration(seconds: 5));

    final second = await recordEvent(AttendanceEventType.checkIn);

    expect((failureOf(second) as ValidationFailure).code, 'ALREADY_CHECKED_IN');
    expect(await outbox.all(), hasLength(1));
  });

  test('two taps at the same moment create exactly one event', () async {
    // Hold the first call inside the GPS lookup while the second arrives.
    location.gate = Completer<void>();
    final first = recordEvent(AttendanceEventType.checkIn);
    final second = recordEvent(AttendanceEventType.checkIn);
    location.gate!.complete();

    final results = await Future.wait([first, second]);

    expect(results.whereType<Success<OutboxEvent>>(), hasLength(1));
    expect(results.whereType<Fail<OutboxEvent>>(), hasLength(1));
    expect(await outbox.all(), hasLength(1));
  });

  test('check-in then check-out queues two events in order', () async {
    await recordEvent(AttendanceEventType.checkIn);
    clock.advance(const Duration(hours: 9));
    final out = await recordEvent(AttendanceEventType.checkOut);

    expect(out.isSuccess, isTrue);
    final events = await outbox.all();
    expect(events.map((e) => e.type),
        [AttendanceEventType.checkIn, AttendanceEventType.checkOut]);
    expect(events[0].seq, lessThan(events[1].seq));
  });

  test('outside the geofence is rejected with the distance', () async {
    location.result = const Success(outsideOffice);

    final result = await recordEvent(AttendanceEventType.checkIn);

    expect(failureOf(result).message, contains("You're 840 m from the office"));
    expect(failureOf(result).message, contains('within 200 m'));
    expect(await outbox.all(), isEmpty);
  });

  test('a location failure is passed through and nothing is queued',
      () async {
    location.result = const Fail(
        LocationFailure('Blocked', issue: LocationIssue.deniedForever));

    final result = await recordEvent(AttendanceEventType.checkIn);

    final failure = failureOf(result) as LocationFailure;
    expect(failure.issue, LocationIssue.deniedForever);
    expect(await outbox.all(), isEmpty);
  });

  test('yesterday\'s open check-in cannot be checked out today', () async {
    await recordEvent(AttendanceEventType.checkIn);
    clock.advance(const Duration(days: 1)); // now Tuesday morning

    final result = await recordEvent(AttendanceEventType.checkOut);

    expect((failureOf(result) as ValidationFailure).code, 'CHECK_IN_REQUIRED');
  });

  test('the working day follows the company timezone, not UTC', () async {
    // 19:00 UTC on the 16th is already 00:30 on the 17th in India.
    clock.now = DateTime.utc(2026, 11, 16, 19, 0);

    final result = await recordEvent(AttendanceEventType.checkIn);

    expect((result as Success<OutboxEvent>).value.workDate, '2026-11-17');
  });

  group('outbox duplicate check (storage-level guard)', () {
    Future<Result<OutboxEvent>> add(String id) => outbox.add(
          eventId: id,
          type: AttendanceEventType.checkIn,
          occurredAt: clock.now,
          workDate: '2026-11-16',
          lat: 0,
          lng: 0,
          accuracy: null,
        );

    test('refuses a second live check-in for the same day', () async {
      expect((await add('a')).isSuccess, isTrue);
      final second = await add('b');
      expect((failureOf(second) as ValidationFailure).code, 'DUPLICATE_EVENT');
    });

    test('allows a new attempt once the first was rejected', () async {
      final first = (await add('a') as Success<OutboxEvent>).value;
      await outbox.markRejected(first.seq, reason: 'Outside geofence');
      expect((await add('b')).isSuccess, isTrue);
    });
  });
}
