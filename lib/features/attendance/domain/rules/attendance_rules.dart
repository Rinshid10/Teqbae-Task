import '../../../../core/error/failures.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../../employee/domain/entities/employee.dart';
import '../../../sync/domain/entities/outbox_event.dart';
import '../entities/attendance_day.dart';
import '../entities/attendance_record.dart';
import '../entities/geo_position.dart';

/// The attendance business rules. Pure functions: no I/O, no clock, no
/// state — everything is passed in, which makes every rule trivially
/// unit-testable.
class AttendanceRules {
  const AttendanceRules();

  /// Merges the server's record for a day with the local outbox events for
  /// the same day.
  ///
  /// For each of check-in / check-out:
  ///   - the server record wins when it has the time (definitely synced);
  ///   - otherwise a local event that is not REJECTED counts, synced or not.
  ///
  /// Counting PENDING events is what blocks an offline double check-in: the
  /// second attempt already sees today as "checked in".
  AttendanceDay buildDay(
    String workDate,
    AttendanceRecord? record,
    List<OutboxEvent> events,
  ) {
    AttendanceMark? mark(AttendanceEventType type, DateTime? serverTime) {
      if (serverTime != null) {
        return AttendanceMark(time: serverTime, isSynced: true);
      }
      final live = events
          .where((e) => e.type == type && e.status != SyncStatus.rejected);
      if (live.isEmpty) return null;
      final event = live.last;
      return AttendanceMark(
        time: event.occurredAt,
        isSynced: event.status == SyncStatus.synced,
      );
    }

    return AttendanceDay(
      workDate: workDate,
      checkIn: mark(AttendanceEventType.checkIn, record?.checkInAt),
      checkOut: mark(AttendanceEventType.checkOut, record?.checkOutAt),
      rejected: [
        for (final e in events)
          if (e.status == SyncStatus.rejected) e,
      ],
    );
  }

  /// Whether [type] is allowed right now. Null means allowed.
  ///
  /// [today] must be the CURRENT company working day. Because of that, a
  /// check-in left open yesterday cannot be closed today ("no overnight
  /// sessions"): today has no check-in, so check-out is refused.
  ValidationFailure? validate(
    AttendanceEventType type,
    AttendanceDay today,
    DateTime nowUtc,
  ) {
    switch (type) {
      case AttendanceEventType.checkIn:
        if (today.checkOut != null) {
          return const ValidationFailure(AppStrings.dayAlreadyComplete,
              code: 'DAY_COMPLETE');
        }
        if (today.checkIn != null) {
          return const ValidationFailure(AppStrings.alreadyCheckedIn,
              code: 'ALREADY_CHECKED_IN');
        }
        return null;

      case AttendanceEventType.checkOut:
        final checkIn = today.checkIn;
        if (checkIn == null) {
          return const ValidationFailure(AppStrings.checkInRequired,
              code: 'CHECK_IN_REQUIRED');
        }
        if (today.checkOut != null) {
          return const ValidationFailure(AppStrings.alreadyCheckedOut,
              code: 'ALREADY_CHECKED_OUT');
        }
        // Only possible if the device clock was moved backwards.
        if (!nowUtc.isAfter(checkIn.time)) {
          return const ValidationFailure(AppStrings.checkOutBeforeCheckIn,
              code: 'INVALID_ORDER');
        }
        return null;
    }
  }

  /// Null when [position] is inside the office radius. The boundary itself
  /// counts as inside.
  ValidationFailure? checkGeofence(
    GeoPosition position,
    Office office,
    AttendanceEventType type,
  ) {
    final distance =
        distanceInMeters(position.lat, position.lng, office.lat, office.lng);
    if (distance <= office.radiusMeters) return null;
    return ValidationFailure(
      AppStrings.outsideGeofence(
        distanceMeters: distance.round(),
        radiusMeters: office.radiusMeters.round(),
        isCheckIn: type == AttendanceEventType.checkIn,
      ),
      code: 'OUTSIDE_GEOFENCE',
    );
  }
}
