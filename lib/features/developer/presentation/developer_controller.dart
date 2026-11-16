import 'package:get/get.dart';

import '../../../app/config/app_config.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/utils/result.dart';
import '../../../core/widgets/app_messenger.dart';
import '../../attendance/data/services/mock_location_service.dart';
import '../../employee/domain/entities/employee.dart';
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
/// location, switch the mock server's scenario, reset everything.
class DeveloperController extends GetxController {
  DeveloperController({
    required DeveloperRepository repository,
    required SwitchableLocationService locationService,
    required GetOffice getOffice,
    required AppConfig config,
  })  : _repository = repository,
        _locationService = locationService,
        _getOffice = getOffice,
        _config = config,
        locationMode = locationService.mode.obs;

  final DeveloperRepository _repository;
  final SwitchableLocationService _locationService;
  final GetOffice _getOffice;
  final AppConfig _config;

  final Rx<LocationMode> locationMode;

  /// The mock server's scenario. Null until it has been read, or when the
  /// server cannot be reached.
  final scenario = Rxn<MockScenario>();

  /// True while a scenario change or reset is in flight.
  final isBusy = false.obs;
  final office = Rxn<OfficeInfoUi>();

  @override
  void onInit() {
    super.onInit();
    _loadOffice();
    _loadScenario();
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

  Future<void> _loadScenario() async {
    final result = await _repository.currentScenario();
    if (isClosed) return;
    scenario.value = result.fold((value) => value, (_) => null);
  }

  /// Takes effect on the next location check; nothing is restarted.
  void selectLocationMode(LocationMode mode) {
    _locationService.mode = mode;
    locationMode.value = mode;
  }

  Future<void> selectScenario(MockScenario value) async {
    if (isBusy.value) return;
    isBusy.value = true;
    try {
      switch (await _repository.setScenario(value)) {
        case Success():
          scenario.value = value;
        case Fail(:final failure):
          // Usually: the mock server is not running or not reachable.
          AppMessenger.show(failure.message);
      }
    } finally {
      isBusy.value = false;
    }
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
      scenario.value = server.isSuccess ? MockScenario.success : null;
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
