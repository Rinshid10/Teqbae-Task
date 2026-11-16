import 'package:flutter_test/flutter_test.dart';
import 'package:rebs_hrms/app/config/app_config.dart';
import 'package:rebs_hrms/core/error/failures.dart';
import 'package:rebs_hrms/core/utils/result.dart';
import 'package:rebs_hrms/features/attendance/data/services/mock_location_service.dart';
import 'package:rebs_hrms/features/attendance/domain/entities/geo_position.dart';
import 'package:rebs_hrms/features/developer/domain/developer_repository.dart';
import 'package:rebs_hrms/features/developer/presentation/developer_controller.dart';
import 'package:rebs_hrms/features/employee/domain/entities/employee.dart';
import 'package:rebs_hrms/features/employee/domain/usecases/get_employee.dart';
import 'package:rebs_hrms/features/employee/domain/usecases/get_office.dart';

import '../../helpers/test_support.dart';

/// Stands in for the mock server: moving the office changes what
/// /employee/me (the employee repository) returns afterwards.
class _FakeDeveloperRepository implements DeveloperRepository {
  _FakeDeveloperRepository(this.employees);

  final FakeEmployeeRepository employees;
  Result<void> answer = const Success(null);
  final moves = <({double lat, double lng})>[];

  @override
  Future<Result<void>> setOffice({
    required double lat,
    required double lng,
  }) async {
    if (answer is Fail) return answer;
    moves.add((lat: lat, lng: lng));
    final e = employees.employee!;
    employees.employee = Employee(
      id: e.id,
      name: e.name,
      department: e.department,
      designation: e.designation,
      office: Office(lat: lat, lng: lng, radiusMeters: e.office.radiusMeters),
      timezone: e.timezone,
    );
    return const Success(null);
  }

  @override
  Future<Result<void>> resetServer() async => const Success(null);

  @override
  Future<void> clearLocalData() async {}
}

/// Moving the office from the Settings screen.
void main() {
  // The controller reports outcomes through AppMessenger, which looks up a
  // GlobalKey and therefore needs the widgets binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeEmployeeRepository employees;
  late _FakeDeveloperRepository repository;
  late FakeLocationService device;
  late GetOffice getOffice;
  late DeveloperController controller;

  // Bengaluru: nowhere near the default office in Kochi.
  const here = GeoPosition(lat: 12.9716, lng: 77.5946, accuracy: 10);

  setUp(() {
    employees = FakeEmployeeRepository(
      employee: const Employee(
        id: 'EMP-1042',
        name: 'Anjali Menon',
        department: 'Engineering',
        designation: 'Software Engineer',
        office: testOffice,
        timezone: 'Asia/Kolkata',
      ),
    );
    repository = _FakeDeveloperRepository(employees);
    device = FakeLocationService(const Success(here));
    getOffice = GetOffice(employees, fallback: testOffice);
    controller = DeveloperController(
      repository: repository,
      locationService: SwitchableLocationService(
        device: device,
        mock: MockLocationService(
            getOffice: getOffice, mode: LocationMode.inside),
        initialMode: LocationMode.inside,
      ),
      getOffice: getOffice,
      getEmployee: GetEmployee(employees),
      deviceLocation: device,
      config: AppConfig.fromEnvironment,
    );
  });

  test('"use my current location" moves the office to the real GPS fix, '
      'even while a simulated location is active', () async {
    await controller.useCurrentLocationAsOffice();

    expect(repository.moves.single, (lat: here.lat, lng: here.lng));
    final office = await getOffice();
    expect(office.lat, here.lat);
    expect(office.lng, here.lng);
    expect(controller.office.value?.coordinates, '12.9716° N, 77.5946° E');
    expect(controller.isBusy.value, isFalse);
    // The button now shows as a disabled "using your current location".
    expect(controller.usingCurrentLocation.value, isTrue);

    // Reset puts the office back, so the button is offered again.
    await controller.resetEverything();
    expect(controller.usingCurrentLocation.value, isFalse);
  });

  test('a location problem leaves the office where it was', () async {
    device.result = const Fail(
        LocationFailure('Location is off.', issue: LocationIssue.serviceDisabled));

    await controller.useCurrentLocationAsOffice();

    expect(repository.moves, isEmpty);
    expect((await getOffice()).lat, testOffice.lat);
    expect(controller.usingCurrentLocation.value, isFalse);
  });

  test('when the server cannot be reached nothing changes', () async {
    repository.answer = const Fail(NetworkFailure());

    await controller.useCurrentLocationAsOffice();

    expect((await getOffice()).lat, testOffice.lat);
    // Not applied, so the button stays available for another try.
    expect(controller.usingCurrentLocation.value, isFalse);
  });
}
