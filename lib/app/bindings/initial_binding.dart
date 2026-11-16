import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/network/connectivity_network_info.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/network_info.dart';
import '../../core/utils/clock.dart';
import '../../core/utils/formatters.dart';
import '../../features/attendance/data/datasources/attendance_local_data_source.dart';
import '../../features/attendance/data/datasources/attendance_remote_data_source.dart';
import '../../features/attendance/data/repositories/attendance_repository_impl.dart';
import '../../features/attendance/data/services/device_location_service.dart';
import '../../features/attendance/data/services/mock_location_service.dart';
import '../../features/attendance/domain/repositories/attendance_repository.dart';
import '../../features/attendance/domain/services/location_service.dart';
import '../../features/attendance/domain/usecases/check_attendance_location.dart';
import '../../features/attendance/domain/usecases/get_attendance_overview.dart';
import '../../features/attendance/domain/usecases/record_attendance_event.dart';
import '../../features/attendance/presentation/models/attendance_ui.dart';
import '../../features/developer/data/developer_repository_impl.dart';
import '../../features/developer/domain/developer_repository.dart';
import '../../features/employee/data/datasources/employee_local_data_source.dart';
import '../../features/employee/data/datasources/employee_remote_data_source.dart';
import '../../features/employee/data/repositories/employee_repository_impl.dart';
import '../../features/employee/domain/entities/employee.dart';
import '../../features/employee/domain/repositories/employee_repository.dart';
import '../../features/employee/domain/usecases/get_employee.dart';
import '../../features/employee/domain/usecases/get_office.dart';
import '../../features/leave/data/datasources/leave_local_data_source.dart';
import '../../features/leave/data/datasources/leave_remote_data_source.dart';
import '../../features/leave/data/repositories/leave_repository_impl.dart';
import '../../features/leave/domain/repositories/leave_repository.dart';
import '../../features/leave/domain/usecases/get_leave_overview.dart';
import '../../features/leave/domain/usecases/submit_leave_request.dart';
import '../../features/leave/domain/usecases/validate_leave_request.dart';
import '../../features/leave/presentation/models/leave_ui.dart';
import '../../features/sync/data/datasources/outbox_local_data_source.dart';
import '../../features/sync/data/repositories/attendance_event_sender_impl.dart';
import '../../features/sync/data/repositories/outbox_repository_impl.dart';
import '../../features/sync/domain/repositories/outbox_repository.dart';
import '../../features/sync/domain/usecases/get_outbox_events.dart';
import '../../features/sync/domain/usecases/process_outbox.dart';
import '../../features/sync/presentation/sync_service.dart';
import '../config/app_config.dart';

/// The composition root: the ONE place where concrete classes are chosen
/// and wired together, registered once before the first route is built.
///
/// GetX is used as a service locator only at the edges (here and in the
/// feature bindings). Use cases, repositories and data sources take what
/// they need through their constructors, which is why every one of them
/// can be built in a test without GetX.
class InitialBinding extends Bindings {
  InitialBinding(this._database);

  /// Opened in main() because opening is async and bindings are not.
  final AppDatabase _database;

  @override
  void dependencies() {
    const config = AppConfig.fromEnvironment;

    // ---- core -------------------------------------------------------------
    // Registered under their abstract types so tests can swap in fakes.
    final Clock clock = SystemClock(config.timezone);
    final NetworkInfo networkInfo = ConnectivityNetworkInfo();
    // In debug builds this Dio logs every request and response.
    final dio = createDio(baseUrl: config.apiBaseUrl);
    final format = AppFormat(clock);

    Get.put<AppConfig>(config, permanent: true);
    Get.put<Clock>(clock, permanent: true);
    Get.put<NetworkInfo>(networkInfo, permanent: true);
    Get.put<Dio>(dio, permanent: true);
    Get.put<AppFormat>(format, permanent: true);
    Get.put(AttendanceUiMapper(format), permanent: true);
    Get.put(LeaveUiMapper(format), permanent: true);

    // ---- repositories -----------------------------------------------------
    final EmployeeRepository employeeRepository = EmployeeRepositoryImpl(
      remote: EmployeeRemoteDataSource(dio),
      local: EmployeeLocalDataSource(_database),
      clock: clock,
    );
    final attendanceRemote = AttendanceRemoteDataSource(dio);
    final AttendanceRepository attendanceRepository = AttendanceRepositoryImpl(
      remote: attendanceRemote,
      local: AttendanceLocalDataSource(_database),
      clock: clock,
    );
    final LeaveRepository leaveRepository = LeaveRepositoryImpl(
      remote: LeaveRemoteDataSource(dio),
      local: LeaveLocalDataSource(_database),
      clock: clock,
    );
    final OutboxRepository outboxRepository = OutboxRepositoryImpl(
      local: OutboxLocalDataSource(_database),
      clock: clock,
    );
    Get.put<OutboxRepository>(outboxRepository, permanent: true);

    // ---- location ---------------------------------------------------------
    final getOffice = GetOffice(
      employeeRepository,
      fallback: Office(
        lat: config.officeLat,
        lng: config.officeLng,
        radiusMeters: config.officeRadiusMeters,
      ),
    );
    final initialMode = LocationMode.fromDefine(config.mockLocation);
    final locationService = SwitchableLocationService(
      device: const DeviceLocationService(),
      mock: MockLocationService(getOffice: getOffice, mode: initialMode),
      initialMode: initialMode,
    );
    // Two registrations of the same object: the domain sees the plain
    // LocationService; only the debug sheet knows it can be switched.
    Get.put<LocationService>(locationService, permanent: true);
    Get.put<SwitchableLocationService>(locationService, permanent: true);

    // ---- use cases --------------------------------------------------------
    const uuid = Uuid();
    Get.put(GetEmployee(employeeRepository), permanent: true);
    Get.put(
      GetAttendanceOverview(
        attendance: attendanceRepository,
        outbox: outboxRepository,
        clock: clock,
      ),
      permanent: true,
    );
    Get.put(
      RecordAttendanceEvent(
        attendance: attendanceRepository,
        outbox: outboxRepository,
        location: locationService,
        getOffice: getOffice,
        clock: clock,
        newEventId: uuid.v4, // the idempotency key
      ),
      permanent: true,
    );
    Get.put(GetLeaveOverview(leaveRepository), permanent: true);
    Get.put(
      ValidateLeaveRequest(repository: leaveRepository, clock: clock),
      permanent: true,
    );
    Get.put(GetOutboxEvents(outboxRepository), permanent: true);
    Get.put(getOffice, permanent: true);
    Get.put(
      CheckAttendanceLocation(
        attendance: attendanceRepository,
        outbox: outboxRepository,
        location: locationService,
        getOffice: getOffice,
        clock: clock,
      ),
      permanent: true,
    );
    // Reviewer tools (mock-server control + local reset).
    Get.put<DeveloperRepository>(
      DeveloperRepositoryImpl(dio: dio, database: _database),
      permanent: true,
    );
    Get.put(
      SubmitLeaveRequest(
        repository: leaveRepository,
        networkInfo: networkInfo,
        clock: clock,
      ),
      permanent: true,
    );

    // ---- sync -------------------------------------------------------------
    // Get.put calls onInit, which starts the first sync run (app start
    // trigger) and the connectivity listener.
    Get.put(
      SyncService(
        processOutbox: ProcessOutbox(
          outbox: outboxRepository,
          sender: AttendanceEventSenderImpl(attendanceRemote),
          attendance: attendanceRepository,
        ),
        outbox: outboxRepository,
        networkInfo: networkInfo,
      ),
      permanent: true,
    );
  }
}
