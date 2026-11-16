import '../../../../core/error/failures.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../sync/domain/entities/outbox_event.dart';
import '../../domain/usecases/check_attendance_location.dart';

/// What the location sheet is showing. Sealed, so the sheet's `switch`
/// must handle every state.
sealed class LocationFlowState {
  const LocationFlowState();
}

/// Waiting for a GPS fix ("Verifying your location").
final class LocationChecking extends LocationFlowState {
  const LocationChecking();
}

/// Inside the geofence: show the result and the Confirm button.
final class LocationReady extends LocationFlowState {
  const LocationReady(this.ready);
  final LocationReadyUi ready;
}

/// Something stopped the check-in: out of range, no permission, GPS off,
/// or an attendance rule.
final class LocationProblem extends LocationFlowState {
  const LocationProblem(this.problem);
  final LocationProblemUi problem;
}

class LocationReadyUi {
  const LocationReadyUi({
    required this.title,
    required this.subtitle,
    required this.markerLabel,
    required this.perimeterLabel,
    required this.timeLabel,
    required this.accuracyLabel,
    required this.confirmLabel,
    required this.distanceFraction,
  });

  final String title; // "You're 45 m from the office"
  final String subtitle; // "Inside the allowed 200 m check-in radius"
  final String markerLabel; // "You · 45 m"
  final String perimeterLabel; // "200 m perimeter"
  final String timeLabel; // "09:12 AM"
  final String? accuracyLabel; // "±8 m accuracy"
  final String confirmLabel; // "Confirm Check In"

  /// Distance as a share of the radius (0 = at the office, 1 = on the
  /// boundary). Positions the "You" marker on the radar.
  final double distanceFraction;
}

/// What the problem state's main button does.
enum ProblemAction { retry, openLocationSettings, openAppSettings, close }

/// Which picture the problem state shows.
enum ProblemKind { outside, locationOff, denied, blocked, unavailable, rule }

class LocationProblemUi {
  const LocationProblemUi({
    required this.kind,
    required this.pill,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.action,
    this.distanceLabel,
    this.zoneLabel,
    this.showRetryLink = false,
  });

  final ProblemKind kind;
  final String pill; // "Out of Range"
  final String title;
  final String body;
  final String actionLabel;
  final ProblemAction action;

  /// "840 m" on the user pin (outside only).
  final String? distanceLabel;

  /// "200 m zone" under the office marker (outside only).
  final String? zoneLabel;

  /// Adds a secondary "Try again" link when the main action opens settings.
  final bool showRetryLink;
}

/// Shown on the confirmation page after a check-in / check-out.
class AttendanceSuccessUi {
  const AttendanceSuccessUi({
    required this.isCheckIn,
    required this.headline,
    required this.subtitle,
    required this.distanceLabel,
  });

  final bool isCheckIn;
  final String headline; // "Checked in at 09:12 AM"
  final String subtitle;
  final String distanceLabel; // "45 m from the office · ±8 m"
}

/// Domain results -> the sheet's display states.
abstract final class LocationFlowMapper {
  static LocationReadyUi ready(
    LocationCheck check,
    AttendanceEventType type, {
    required String timeLabel,
  }) {
    final distance = check.distanceMeters.round();
    final radius = check.office.radiusMeters.round();
    final accuracy = check.position.accuracy;
    return LocationReadyUi(
      title: AppStrings.youAreFromOffice(distance),
      subtitle: AppStrings.insideRadius(radius),
      markerLabel: AppStrings.youMarker(distance),
      perimeterLabel: AppStrings.perimeter(radius),
      timeLabel: timeLabel,
      accuracyLabel:
          accuracy == null ? null : AppStrings.accuracy(accuracy.round()),
      confirmLabel: type == AttendanceEventType.checkIn
          ? AppStrings.confirmCheckIn
          : AppStrings.confirmCheckOut,
      distanceFraction:
          (check.distanceMeters / check.office.radiusMeters).clamp(0.0, 1.0),
    );
  }

  static LocationProblemUi outside(
    LocationCheck check,
    AttendanceEventType type,
  ) {
    final distance = check.distanceMeters.round();
    final radius = check.office.radiusMeters.round();
    return LocationProblemUi(
      kind: ProblemKind.outside,
      pill: AppStrings.outOfRange,
      title: AppStrings.outsideTitle,
      body: AppStrings.outsideGeofence(
        distanceMeters: distance,
        radiusMeters: radius,
        isCheckIn: type == AttendanceEventType.checkIn,
      ),
      actionLabel: AppStrings.retry,
      action: ProblemAction.retry,
      distanceLabel: AppStrings.metres(distance),
      zoneLabel: AppStrings.zone(radius),
    );
  }

  /// Each location problem gets its own message and its own way out.
  static LocationProblemUi failure(Failure failure) {
    if (failure is LocationFailure) {
      return switch (failure.issue) {
        LocationIssue.serviceDisabled => LocationProblemUi(
            kind: ProblemKind.locationOff,
            pill: AppStrings.pillLocationOff,
            title: AppStrings.locationOffTitle,
            body: failure.message,
            actionLabel: AppStrings.actionTurnOnLocation,
            action: ProblemAction.openLocationSettings,
            showRetryLink: true,
          ),
        // After a plain deny the OS shows its prompt again on retry.
        LocationIssue.denied => LocationProblemUi(
            kind: ProblemKind.denied,
            pill: AppStrings.pillPermission,
            title: AppStrings.locationDeniedTitle,
            body: failure.message,
            actionLabel: AppStrings.actionAllowLocation,
            action: ProblemAction.retry,
          ),
        LocationIssue.deniedForever => LocationProblemUi(
            kind: ProblemKind.blocked,
            pill: AppStrings.pillBlocked,
            title: AppStrings.locationBlockedTitle,
            body: failure.message,
            actionLabel: AppStrings.actionOpenAppSettings,
            action: ProblemAction.openAppSettings,
            showRetryLink: true,
          ),
        LocationIssue.timeout || LocationIssue.unavailable => LocationProblemUi(
            kind: ProblemKind.unavailable,
            pill: AppStrings.pillNoGps,
            title: AppStrings.locationUnavailableTitle,
            body: failure.message,
            actionLabel: AppStrings.retry,
            action: ProblemAction.retry,
          ),
      };
    }
    // An attendance rule (already checked in, check in first, ...) or a
    // storage error: nothing to retry, just explain and close.
    return LocationProblemUi(
      kind: ProblemKind.rule,
      pill: AppStrings.pillNotAllowed,
      title: AppStrings.notAllowedTitle,
      body: failure.message,
      actionLabel: AppStrings.gotIt,
      action: ProblemAction.close,
    );
  }
}
