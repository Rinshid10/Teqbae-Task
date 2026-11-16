import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rebs_hrms/core/database/app_database.dart';
import 'package:rebs_hrms/core/error/failures.dart';
import 'package:rebs_hrms/core/strings/app_strings.dart';
import 'package:rebs_hrms/core/utils/cached.dart';
import 'package:rebs_hrms/core/utils/formatters.dart';
import 'package:rebs_hrms/core/utils/result.dart';
import 'package:rebs_hrms/core/utils/view_state.dart';
import 'package:rebs_hrms/features/attendance/domain/entities/attendance_day.dart';
import 'package:rebs_hrms/features/attendance/domain/entities/attendance_record.dart';
import 'package:rebs_hrms/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:rebs_hrms/features/attendance/domain/usecases/get_attendance_overview.dart';
import 'package:rebs_hrms/features/attendance/presentation/models/attendance_ui.dart';
import 'package:rebs_hrms/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:rebs_hrms/features/employee/domain/entities/employee.dart';
import 'package:rebs_hrms/features/employee/domain/repositories/employee_repository.dart';
import 'package:rebs_hrms/features/employee/domain/usecases/get_employee.dart';
import 'package:rebs_hrms/features/leave/domain/repositories/leave_repository.dart';
import 'package:rebs_hrms/features/leave/domain/usecases/get_leave_overview.dart';
import 'package:rebs_hrms/features/sync/data/datasources/outbox_local_data_source.dart';
import 'package:rebs_hrms/features/sync/data/repositories/outbox_repository_impl.dart';
import 'package:rebs_hrms/features/sync/domain/entities/outbox_event.dart';
import 'package:rebs_hrms/features/sync/domain/usecases/process_outbox.dart';
import 'package:rebs_hrms/features/sync/presentation/sync_service.dart';

import '../../helpers/test_support.dart';

class _MockEmployeeRepository extends Mock implements EmployeeRepository {}

class _MockAttendanceRepository extends Mock implements AttendanceRepository {}

class _MockLeaveRepository extends Mock implements LeaveRepository {}

/// What Home shows when the server cannot be reached.
void main() {
  late AppDatabase database;
  late OutboxRepositoryImpl outbox;
  late _MockEmployeeRepository employees;
  late _MockAttendanceRepository attendance;
  late _MockLeaveRepository leave;
  late DashboardController controller;
  final clock = FakeClock.mondayMorning();

  const employee = Employee(
    id: 'EMP-1042',
    name: 'Anjali Menon',
    department: 'Engineering',
    designation: 'Software Engineer',
    office: testOffice,
    timezone: 'Asia/Kolkata',
  );

  /// Makes every repository answer as if the request failed with [failure]
  /// and nothing had ever been cached.
  void serverFails(Failure failure) {
    when(() => employees.getEmployee(refresh: any(named: 'refresh')))
        .thenAnswer((_) async => Fail(failure));
    when(() => attendance.getRecords(refresh: any(named: 'refresh')))
        .thenAnswer((_) async => Fail(failure));
    when(() => attendance.cachedRecords()).thenAnswer((_) async => null);
    when(() => attendance.cachedRecordFor(any())).thenAnswer((_) async => null);
    when(() => leave.getBalances(refresh: any(named: 'refresh')))
        .thenAnswer((_) async => Fail(failure));
    when(() => leave.getRequests(refresh: any(named: 'refresh')))
        .thenAnswer((_) async => Fail(failure));
  }

  setUp(() async {
    database = await openTestDatabase();
    outbox = OutboxRepositoryImpl(
        local: OutboxLocalDataSource(database), clock: clock);
    employees = _MockEmployeeRepository();
    attendance = _MockAttendanceRepository();
    leave = _MockLeaveRepository();

    final format = AppFormat(clock);
    final getAttendance = GetAttendanceOverview(
        attendance: attendance, outbox: outbox, clock: clock);
    controller = DashboardController(
      getEmployee: GetEmployee(employees),
      getAttendance: getAttendance,
      getLeave: GetLeaveOverview(leave),
      outbox: outbox,
      // Not started (no onInit): only its observables are read.
      sync: SyncService(
        processOutbox: ProcessOutbox(
            outbox: outbox,
            sender: FakeSender(),
            attendance: attendance),
        outbox: outbox,
        networkInfo: FakeNetworkInfo(connected: false),
      ),
      clock: clock,
      format: format,
      attendanceMapper: AttendanceUiMapper(format),
    );
  });

  tearDown(() async {
    controller.onClose();
    await database.close();
  });

  DashboardData shown() =>
      (controller.state.value as ViewData<DashboardData>).value;

  test(
      'first launch with no connection: Home still opens, in offline mode, '
      'instead of an error screen', () async {
    serverFails(const TimeoutFailure());

    await controller.load();

    expect(controller.state.value, isA<ViewData<DashboardData>>());
    final data = shown();
    expect(data.greeting, AppStrings.goodMorning); // no name yet
    expect(data.employeeId, AppStrings.profileNotLoaded);
    expect(data.status, TodayStatus.notCheckedIn);
    expect(data.offlineMessage, AppStrings.offlineBannerNoTime);
    expect((controller.state.value as ViewData).isOffline, isTrue);
  });

  test('an offline check-in then shows on Home straight away', () async {
    serverFails(const NetworkFailure());
    await controller.load();

    await outbox.add(
      eventId: 'evt-1',
      type: AttendanceEventType.checkIn,
      occurredAt: clock.now,
      workDate: '2026-11-16',
      lat: testOffice.lat,
      lng: testOffice.lng,
      accuracy: 8,
    );
    await controller.load(refresh: false);

    final data = shown();
    expect(data.status, TodayStatus.checkedIn);
    expect(data.checkIn, '09:00 AM');
    expect(data.recent.single.metaLabel, contains(AppStrings.storedLocally));
  });

  test('a server error (500) with nothing saved is a real error state',
      () async {
    serverFails(const ServerFailure('Simulated server error.', statusCode: 500));

    await controller.load();

    final state = controller.state.value;
    expect(state, isA<ViewError<DashboardData>>());
    expect((state as ViewError).message, 'Simulated server error.');
  });

  test('saved data is shown with the "last updated" banner when offline',
      () async {
    final fetchedAt = DateTime.utc(2026, 11, 16, 2, 0); // 07:30 company time
    const failure = NetworkFailure();
    serverFails(failure);
    when(() => employees.getEmployee(refresh: any(named: 'refresh')))
        .thenAnswer((_) async => Success(Cached(employee,
            fetchedAt: fetchedAt, isStale: true, refreshError: failure)));
    when(() => attendance.getRecords(refresh: any(named: 'refresh')))
        .thenAnswer((_) async => Success(Cached(const <AttendanceRecord>[],
            fetchedAt: fetchedAt, isStale: true, refreshError: failure)));

    await controller.load();

    final data = shown();
    expect(data.greeting, 'Good morning, Anjali');
    expect(data.employeeId, 'EMP-1042');
    expect(data.offlineMessage,
        'Showing saved data · last updated 07:30 AM');
  });
}
