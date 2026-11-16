import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/geo_position.dart';
import '../../domain/services/location_service.dart';

/// The real GPS, via geolocator. Every way it can fail is turned into a
/// LocationFailure with its own `issue`, so the UI can offer the matching
/// fix instead of a generic error.
class DeviceLocationService implements LocationService {
  const DeviceLocationService({this.timeLimit = const Duration(seconds: 10)});

  /// How long to wait for a fix before giving up (indoors GPS can hang).
  final Duration timeLimit;

  @override
  Future<Result<GeoPosition>> currentPosition() async {
    try {
      // 1. Is location switched on for the whole device?
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const Fail(LocationFailure(AppStrings.locationServiceOff,
            issue: LocationIssue.serviceDisabled));
      }

      // 2. Does this app have permission? Ask if it has not been decided.
      //    After a plain "deny" the OS lets us ask again next time, which is
      //    why the UI's action for `denied` is simply to retry.
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const Fail(LocationFailure(AppStrings.locationDenied,
            issue: LocationIssue.denied));
      }
      if (permission == LocationPermission.deniedForever) {
        // The OS will not show the prompt again; only Settings can fix it.
        return const Fail(LocationFailure(AppStrings.locationDeniedForever,
            issue: LocationIssue.deniedForever));
      }

      // 3. Get a fix.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeLimit,
        ),
      );
      return Success(GeoPosition(
        lat: position.latitude,
        lng: position.longitude,
        accuracy: position.accuracy,
      ));
    } on TimeoutException {
      return const Fail(LocationFailure(AppStrings.locationTimeout,
          issue: LocationIssue.timeout));
    } on LocationServiceDisabledException {
      // Switched off between step 1 and step 3.
      return const Fail(LocationFailure(AppStrings.locationServiceOff,
          issue: LocationIssue.serviceDisabled));
    } catch (_) {
      return const Fail(LocationFailure(AppStrings.locationUnavailable,
          issue: LocationIssue.unavailable));
    }
  }

  @override
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  @override
  Future<void> openAppSettings() => Geolocator.openAppSettings();
}
