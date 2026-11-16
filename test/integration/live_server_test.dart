@Tags(['live'])
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebs_hrms/core/database/app_database.dart';
import 'package:rebs_hrms/core/error/failures.dart';
import 'package:rebs_hrms/core/network/dio_client.dart';
import 'package:rebs_hrms/core/utils/clock.dart';
import 'package:rebs_hrms/core/utils/result.dart';
import 'package:rebs_hrms/features/attendance/data/datasources/attendance_local_data_source.dart';
import 'package:rebs_hrms/features/attendance/data/datasources/attendance_remote_data_source.dart';
import 'package:rebs_hrms/features/attendance/data/repositories/attendance_repository_impl.dart';
import 'package:rebs_hrms/features/attendance/domain/usecases/record_attendance_event.dart';
import 'package:rebs_hrms/features/employee/data/datasources/employee_local_data_source.dart';
import 'package:rebs_hrms/features/employee/data/datasources/employee_remote_data_source.dart';
import 'package:rebs_hrms/features/employee/data/repositories/employee_repository_impl.dart';
import 'package:rebs_hrms/features/employee/domain/usecases/get_office.dart';
import 'package:rebs_hrms/features/leave/data/datasources/leave_local_data_source.dart';
import 'package:rebs_hrms/features/leave/data/datasources/leave_remote_data_source.dart';
import 'package:rebs_hrms/features/leave/data/repositories/leave_repository_impl.dart';
import 'package:rebs_hrms/features/leave/domain/entities/leave.dart';
import 'package:rebs_hrms/features/sync/data/datasources/outbox_local_data_source.dart';
import 'package:rebs_hrms/features/sync/data/repositories/attendance_event_sender_impl.dart';
import 'package:rebs_hrms/features/sync/data/repositories/outbox_repository_impl.dart';
import 'package:rebs_hrms/features/sync/domain/entities/outbox_event.dart';
import 'package:rebs_hrms/features/sync/domain/usecases/process_outbox.dart';
import 'package:timezone/data/latest_10y.dart' as tz_data;

import '../helpers/test_support.dart';

/// The app's real data layer (Dio, repositories, Hive, sync) talking to
/// the real mock server over HTTP. Proves the two sides agree on the wire
/// format, which the unit tests (each side alone) cannot.
///
/// Skipped unless a server URL is given:
///
///   cd mock_server && dart run bin/server.dart --port 8090
///   $env:MOCK_SERVER_URL="http://localhost:8090"; flutter test test/integration
///
/// The timeout test waits out the 8 s receive timeout, so this file is slow.
void main() {
  final baseUrl = Platform.environment['MOCK_SERVER_URL'];
  final skip = baseUrl == null ? 'set MOCK_SERVER_URL to run' : null;

  late Dio dio;
  late AppDatabase database;
  late Clock clock;
  late OutboxRepositoryImpl outbox;
  late AttendanceRepositoryImpl attendance;
  late EmployeeRepositoryImpl employees;
  late LeaveRepositoryImpl leave;
  late RecordAttendanceEvent recordEvent;
  late ProcessOutbox processOutbox;
  late FakeLocationService location;

  Future<void> setScenario(String name) =>
      dio.post<dynamic>('/__mock/scenario', data: {'name': name});

  setUpAll(tz_data.initializeTimeZones);

  setUp(() async {
    if (baseUrl == null) return;
    dio = createDio(baseUrl: baseUrl, enableLogs: false);
    await dio.post<dynamic>('/__mock/reset');

    database = await openTestDatabase();
    clock = SystemClock('Asia/Kolkata'); // real time: the server checks it
    outbox = OutboxRepositoryImpl(
        local: OutboxLocalDataSource(database), clock: clock);
    final remote = AttendanceRemoteDataSource(dio);
    attendance = AttendanceRepositoryImpl(
        remote: remote,
        local: AttendanceLocalDataSource(database),
        clock: clock);
    employees = EmployeeRepositoryImpl(
        remote: EmployeeRemoteDataSource(dio),
        local: EmployeeLocalDataSource(database),
        clock: clock);
    leave = LeaveRepositoryImpl(
        remote: LeaveRemoteDataSource(dio),
        local: LeaveLocalDataSource(database),
        clock: clock);
    location = FakeLocationService();
    var n = 0;
    final runId = DateTime.now().microsecondsSinceEpoch;
    recordEvent = RecordAttendanceEvent(
      attendance: attendance,
      outbox: outbox,
      location: location,
      getOffice: GetOffice(employees, fallback: testOffice),
      clock: clock,
      newEventId: () => 'live-$runId-${++n}',
    );
    processOutbox = ProcessOutbox(
      outbox: outbox,
      sender: AttendanceEventSenderImpl(remote),
      attendance: attendance,
    );
  });

  tearDown(() async {
    if (baseUrl == null) return;
    await setScenario('success');
    await database.close();
  });

  test('reads: employee, attendance, leave are parsed and cached', () async {
    final employee = await employees.getEmployee();
    expect(employee.isSuccess, isTrue);
    expect((await employees.cachedEmployee())?.office.radiusMeters, 200);

    final records = await attendance.getRecords();
    expect(records.fold((c) => c.value.length, (_) => -1), 10);

    final balances = await leave.getBalances();
    expect(balances.fold((c) => c.value.length, (_) => -1), 2);
    final requests = await leave.getRequests();
    expect(requests.fold((c) => c.value.length, (_) => -1), 3);
  }, skip: skip);

  test('check-in and check-out sync to the server', () async {
    final today = clock.workDateOf(clock.nowUtc());

    expect((await recordEvent(AttendanceEventType.checkIn)).isSuccess, isTrue);
    final first = await processOutbox();
    expect(first.synced, 1);
    expect((await attendance.cachedRecordFor(today))?.checkOutAt, isNull);

    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect((await recordEvent(AttendanceEventType.checkOut)).isSuccess, isTrue);
    final second = await processOutbox();
    expect(second.synced, 1);
    expect((await attendance.cachedRecordFor(today))?.checkOutAt, isNotNull);
  }, skip: skip);

  test(
      'timeout after the server saved it: the retry reuses the event_id and '
      'the server keeps ONE record', () async {
    final today = clock.workDateOf(clock.nowUtc());
    await recordEvent(AttendanceEventType.checkIn);

    await setScenario('timeout_after_commit');
    final first = await processOutbox();
    expect(first.blockedBy, isA<TimeoutFailure>());
    expect((await outbox.all()).single.status, SyncStatus.pending);

    await setScenario('success');
    final retry = await processOutbox();
    expect(retry.synced, 1);
    expect((await outbox.all()).single.status, SyncStatus.synced);

    final records = await attendance.getRecords();
    final todays = records.fold(
        (c) => c.value.where((r) => r.workDate == today).length, (_) => -1);
    expect(todays, 1);
  }, skip: skip, timeout: const Timeout(Duration(seconds: 60)));

  test('server_error keeps the event pending; duplicate_attendance rejects it',
      () async {
    await recordEvent(AttendanceEventType.checkIn);

    await setScenario('server_error');
    expect((await processOutbox()).blockedBy, isA<ServerFailure>());
    expect((await outbox.all()).single.status, SyncStatus.pending);

    await setScenario('duplicate_attendance');
    expect((await processOutbox()).rejected, 1);
    final event = (await outbox.all()).single;
    expect(event.status, SyncStatus.rejected);
    expect(event.lastError, isNotEmpty);
  }, skip: skip);

  test('the server re-checks the geofence even if the client did not',
      () async {
    // Bypass the client rules by writing straight to the outbox.
    final now = clock.nowUtc();
    await outbox.add(
      eventId: 'live-outside-${now.microsecondsSinceEpoch}',
      type: AttendanceEventType.checkIn,
      occurredAt: now,
      workDate: clock.workDateOf(now),
      lat: outsideOffice.lat,
      lng: outsideOffice.lng,
      accuracy: 10,
    );

    final result = await processOutbox();

    expect(result.rejected, 1);
    expect((await outbox.all()).single.lastError, contains('from the office'));
  }, skip: skip);

  test('leave: a valid request is created; a 422 maps to field errors',
      () async {
    final start = clock.today().add(const Duration(days: 30));
    final draft = LeaveDraft(
      type: LeaveType.sick,
      startDate: start,
      endDate: start.add(const Duration(days: 1)),
      reason: 'Recovering from a fever',
    );

    final created = await leave.submit(draft);
    expect(created.isSuccess, isTrue);

    // The same dates again: the server reports an overlap on start_date.
    final again = await leave.submit(draft);
    final failure = (again as Fail<LeaveRequest>).failure as RejectedFailure;
    expect(failure.code, 'LEAVE_OVERLAP');
    expect(failure.fieldErrors.keys, contains('start_date'));

    await setScenario('leave_validation');
    final forced = await leave.submit(draft);
    final forcedFailure =
        (forced as Fail<LeaveRequest>).failure as RejectedFailure;
    expect(forcedFailure.fieldErrors.keys, containsAll(['reason', 'start_date']));
  }, skip: skip);
}
