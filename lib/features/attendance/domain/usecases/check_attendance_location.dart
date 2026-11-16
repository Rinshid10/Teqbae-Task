import '../../../../core/utils/clock.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../../../core/utils/result.dart';
import '../../../employee/domain/entities/employee.dart';
import '../../../employee/domain/usecases/get_office.dart';
import '../../../sync/domain/entities/outbox_event.dart';
import '../../../sync/domain/repositories/outbox_repository.dart';
import '../entities/geo_position.dart';
import '../repositories/attendance_repository.dart';
import '../rules/attendance_rules.dart';
import '../services/location_service.dart';

/// Where the user is relative to the office, measured just now.
class LocationCheck {
  const LocationCheck({
    required this.position,
    required this.office,
    required this.distanceMeters,
    required this.checkedAt,
  });

  final GeoPosition position;
  final Office office;
  final double distanceMeters;
  final DateTime checkedAt; // UTC

  /// The boundary itself counts as inside (same rule as AttendanceRules).
  bool get isInside => distanceMeters <= office.radiusMeters;
}

/// The "Verifying your location" step shown before a check-in/out is
/// confirmed. It records nothing.
///
/// The attendance rules run FIRST, so "you already checked in" is reported
/// straight away instead of after a GPS wait. An out-of-range position is a
/// successful result (with `isInside == false`) because the screen needs the
/// distance to explain it; only a missing position is a failure.
class CheckAttendanceLocation {
  const CheckAttendanceLocation({
    required AttendanceRepository attendance,
    required OutboxRepository outbox,
    required LocationService location,
    required GetOffice getOffice,
    required Clock clock,
    AttendanceRules rules = const AttendanceRules(),
  })  : _attendance = attendance,
        _outbox = outbox,
        _location = location,
        _getOffice = getOffice,
        _clock = clock,
        _rules = rules;

  final AttendanceRepository _attendance;
  final OutboxRepository _outbox;
  final LocationService _location;
  final GetOffice _getOffice;
  final Clock _clock;
  final AttendanceRules _rules;

  Future<Result<LocationCheck>> call(AttendanceEventType type) async {
    final now = _clock.nowUtc();
    final workDate = _clock.workDateOf(now);

    final today = _rules.buildDay(
      workDate,
      await _attendance.cachedRecordFor(workDate),
      await _outbox.forWorkDate(workDate),
    );
    final ruleFailure = _rules.validate(type, today, now);
    if (ruleFailure != null) return Fail(ruleFailure);

    switch (await _location.currentPosition()) {
      case Fail(:final failure):
        return Fail(failure);
      case Success(value: final position):
        final office = await _getOffice();
        return Success(LocationCheck(
          position: position,
          office: office,
          distanceMeters: distanceInMeters(
              position.lat, position.lng, office.lat, office.lng),
          checkedAt: _clock.nowUtc(),
        ));
    }
  }
}
