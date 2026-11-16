import '../../../../core/error/failures.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/utils/result.dart';
import '../../../employee/domain/usecases/get_office.dart';
import '../../domain/entities/geo_position.dart';
import '../../domain/services/location_service.dart';

/// Which location behaviour is active. `device` is the real GPS; the rest
/// are simulations for reviewers.
enum LocationMode {
  device(''),
  inside('inside'),
  outside('outside'),
  denied('denied'),
  deniedForever('denied_forever'),
  unavailable('unavailable');

  const LocationMode(this.defineValue);

  /// The value accepted by --dart-define=MOCK_LOCATION=...
  final String defineValue;

  /// Unknown or empty values fall back to the real GPS.
  static LocationMode fromDefine(String value) => values.firstWhere(
        (m) => m.defineValue == value.trim().toLowerCase(),
        orElse: () => LocationMode.device,
      );
}

/// A scripted LocationService: returns a fixed position relative to the
/// office, or a fixed failure. No plugin is touched.
class MockLocationService implements LocationService {
  MockLocationService({required GetOffice getOffice, required this.mode})
      : _getOffice = getOffice;

  final GetOffice _getOffice;
  LocationMode mode;

  // One degree of latitude is about 111.2 km everywhere on Earth, so these
  // offsets north of the office give a known distance.
  static const _insideOffsetDeg = 0.00027; // about 30 m
  static const _outsideOffsetDeg = 0.00755; // about 840 m

  @override
  Future<Result<GeoPosition>> currentPosition() async {
    // A short pause so the button's spinner is visible, as with real GPS.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final office = await _getOffice();

    switch (mode) {
      case LocationMode.inside:
      case LocationMode.device: // not used; SwitchableLocationService routes it
        return Success(GeoPosition(
          lat: office.lat + _insideOffsetDeg,
          lng: office.lng,
          accuracy: 8,
        ));
      case LocationMode.outside:
        return Success(GeoPosition(
          lat: office.lat + _outsideOffsetDeg,
          lng: office.lng,
          accuracy: 12,
        ));
      case LocationMode.denied:
        return const Fail(LocationFailure(AppStrings.locationDenied,
            issue: LocationIssue.denied));
      case LocationMode.deniedForever:
        return const Fail(LocationFailure(AppStrings.locationDeniedForever,
            issue: LocationIssue.deniedForever));
      case LocationMode.unavailable:
        return const Fail(LocationFailure(AppStrings.locationUnavailable,
            issue: LocationIssue.unavailable));
    }
  }

  // Nothing to open for a simulated location.
  @override
  Future<void> openLocationSettings() async {}

  @override
  Future<void> openAppSettings() async {}
}

/// The LocationService the app actually registers. It forwards to the real
/// GPS or to the mock depending on [mode], which the hidden debug sheet can
/// change while the app is running.
class SwitchableLocationService implements LocationService {
  SwitchableLocationService({
    required LocationService device,
    required MockLocationService mock,
    required LocationMode initialMode,
  })  : _device = device,
        _mock = mock,
        _mode = initialMode {
    _mock.mode = initialMode;
  }

  final LocationService _device;
  final MockLocationService _mock;
  LocationMode _mode;

  LocationMode get mode => _mode;

  set mode(LocationMode value) {
    _mode = value;
    _mock.mode = value;
  }

  LocationService get _active =>
      _mode == LocationMode.device ? _device : _mock;

  @override
  Future<Result<GeoPosition>> currentPosition() => _active.currentPosition();

  @override
  Future<void> openLocationSettings() => _active.openLocationSettings();

  @override
  Future<void> openAppSettings() => _active.openAppSettings();
}
