import '../../../../core/error/failures.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/result.dart';
import '../../../employee/domain/usecases/get_office.dart';
import '../../../sync/domain/entities/outbox_event.dart';
import '../../../sync/domain/repositories/outbox_repository.dart';
import '../entities/geo_position.dart';
import '../repositories/attendance_repository.dart';
import '../rules/attendance_rules.dart';
import '../services/location_service.dart';

/// Check in or check out.
///
/// Steps: rules -> location -> geofence -> write to the outbox.
/// It does NOT talk to the server. Online and offline take exactly the same
/// path; the SyncService delivers the event afterwards. One code path means
/// the offline case is exercised every single time the feature is used.
class RecordAttendanceEvent {
  RecordAttendanceEvent({
    required AttendanceRepository attendance,
    required OutboxRepository outbox,
    required LocationService location,
    required GetOffice getOffice,
    required Clock clock,
    required String Function() newEventId,
    AttendanceRules rules = const AttendanceRules(),
  })  : _attendance = attendance,
        _outbox = outbox,
        _location = location,
        _getOffice = getOffice,
        _clock = clock,
        _newEventId = newEventId,
        _rules = rules;

  final AttendanceRepository _attendance;
  final OutboxRepository _outbox;
  final LocationService _location;
  final GetOffice _getOffice;
  final Clock _clock;

  /// Creates the UUID v4 that becomes the idempotency key. Injected so the
  /// domain needs no package and tests can use predictable ids.
  final String Function() _newEventId;
  final AttendanceRules _rules;

  /// Duplicate-tap guard at the domain level. Getting a GPS fix can take
  /// seconds; a second call arriving in that window is refused here even if
  /// some caller forgot its own lock. (The outbox's own duplicate check is the
  /// third and final guard.)
  bool _inFlight = false;

  /// [position] is the fix already taken by the "verify location" step, so
  /// the user is not made to wait for GPS twice. When it is null a fresh
  /// fix is requested. Either way the rules and the geofence are checked
  /// again here: this use case never trusts that an earlier step ran.
  Future<Result<OutboxEvent>> call(
    AttendanceEventType type, {
    GeoPosition? position,
  }) async {
    if (_inFlight) {
      return const Fail(ValidationFailure(AppStrings.attendanceInProgress,
          code: 'IN_PROGRESS'));
    }
    _inFlight = true;
    try {
      // The moment of the tap is the event time, not the moment the GPS
      // fix arrives a few seconds later.
      final now = _clock.nowUtc();
      final workDate = _clock.workDateOf(now);

      // 1. Rules, checked against server cache + local outbox (so events
      //    that are still PENDING count).
      final today = _rules.buildDay(
        workDate,
        await _attendance.cachedRecordFor(workDate),
        await _outbox.forWorkDate(workDate),
      );
      final ruleFailure = _rules.validate(type, today, now);
      if (ruleFailure != null) return Fail(ruleFailure);

      // 2. Location (permission, GPS on, fix within the time limit).
      final GeoPosition fix;
      if (position != null) {
        fix = position;
      } else {
        switch (await _location.currentPosition()) {
          case Success(:final value):
            fix = value;
          case Fail(:final failure):
            return Fail(failure);
        }
      }

      // 3. Geofence.
      final geofenceFailure =
          _rules.checkGeofence(fix, await _getOffice(), type);
      if (geofenceFailure != null) return Fail(geofenceFailure);

      // 4. Outbox. From here the event survives an app restart.
      return _outbox.add(
        eventId: _newEventId(),
        type: type,
        occurredAt: now,
        workDate: workDate,
        lat: fix.lat,
        lng: fix.lng,
        accuracy: fix.accuracy,
      );
    } finally {
      _inFlight = false;
    }
  }
}
