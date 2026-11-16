import 'package:get/get.dart';

import '../../../app/config/app_config.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/widgets/app_messenger.dart';
import '../../../core/utils/result.dart';
import '../../attendance/data/services/mock_location_service.dart';
import '../../attendance/domain/services/location_service.dart';
import '../../employee/domain/entities/employee.dart';
import '../../employee/domain/usecases/get_employee.dart';
import '../../employee/domain/usecases/get_office.dart';
import '../domain/developer_repository.dart';

/// Read-only office values shown at the bottom of Developer Settings.
class OfficeInfoUi {
  const OfficeInfoUi({
    required this.coordinates,
    required this.radius,
    required this.timezone,
    required this.server,
  });

  final String coordinates; // "9.9312° N, 76.2673° E"
  final String radius; // "200 m geofence"
  final String timezone; // "Asia/Kolkata"
  final String server; // API base URL
}

/// Backs the Developer Settings screen (for reviewers): simulate a
/// location, reset everything.
class DeveloperController extends GetxController {
  DeveloperController({
    required DeveloperRepository repository,
    required SwitchableLocationService locationService,
    required GetOffice getOffice,
    required GetEmployee getEmployee,
    required LocationService deviceLocation,
    required AppConfig config,
  })  : _repository = repository,
        _locationService = locationService,
        _getOffice = getOffice,
        _getEmployee = getEmployee,
        _deviceLocation = deviceLocation,
        _config = config,
        locationMode = locationService.mode.obs;

  final DeveloperRepository _repository;
  final SwitchableLocationService _locationService;
  final GetOffice _getOffice;
  final GetEmployee _getEmployee;

  /// The real GPS, whatever location mode is being simulated.
  final LocationService _deviceLocation;
  final AppConfig _config;

  final Rx<LocationMode> locationMode;

  /// True while a reset or an office change is in flight.
  final isBusy = false.obs;
  final office = Rxn<OfficeInfoUi>();

  /// True once "use my current location" has been applied in this run of
  /// the app. The button is then shown as a disabled status; the reset
  /// button puts the office back and enables it again.
  final usingCurrentLocation = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadOffice();
  }

  Future<void> _loadOffice() async {
    final Office value = await _getOffice();
    String degrees(double v, String positive, String negative) =>
        '${v.abs().toStringAsFixed(4)}° ${v >= 0 ? positive : negative}';
    office.value = OfficeInfoUi(
      coordinates:
          '${degrees(value.lat, 'N', 'S')}, ${degrees(value.lng, 'E', 'W')}',
      radius: AppStrings.geofenceRadius(value.radiusMeters.round()),
      timezone: _config.timezone,
      server: _config.apiBaseUrl,
    );
  }

  /// Takes effect on the next location check; nothing is restarted.
  void selectLocationMode(LocationMode mode) {
    _locationService.mode = mode;
    locationMode.value = mode;
  }

  /// Moves the office to where the device really is, so attendance can be
  /// tested with real GPS from anywhere.
  Future<void> useCurrentLocationAsOffice() async {
    if (isBusy.value) return;
    isBusy.value = true;
    try {
      switch (await _deviceLocation.currentPosition()) {
        case Success(:final value):
          usingCurrentLocation.value =
              await _applyOffice(value.lat, value.lng);
        case Fail(:final failure):
          // Permission denied, location off, no fix: say which.
          AppMessenger.show(failure.message);
      }
    } finally {
      isBusy.value = false;
    }
  }

  /// The server is the one place the office is stored: it is changed
  /// there, then read back through /employee/me into the local cache. That
  /// way the app's geofence check and the server's re-check cannot differ.
  Future<bool> _applyOffice(double lat, double lng) async {
    final result = await _repository.setOffice(lat: lat, lng: lng);
    if (result case Fail(:final failure)) {
      AppMessenger.show(failure.message);
      return false;
    }
    await _getEmployee(refresh: true);
    await _loadOffice();
    AppMessenger.show(AppStrings.devOfficeUpdated);
    return true;
  }

  /// Resets the mock server and wipes local data. Returns true when the
  /// local wipe happened, so the view can restart the app's screens.
  Future<bool> resetEverything() async {
    if (isBusy.value) return false;
    isBusy.value = true;
    try {
      // Best effort: local data is cleared even if the server is down.
      final server = await _repository.resetServer();
      await _repository.clearLocalData();
      // The server put the office back to its default.
      if (server.isSuccess) usingCurrentLocation.value = false;
      AppMessenger.show(server.isSuccess
          ? AppStrings.devResetDone
          : AppStrings.devResetLocalOnly);
      return true;
    } catch (_) {
      AppMessenger.show(AppStrings.cacheError);
      return false;
    } finally {
      isBusy.value = false;
    }
  }
}
