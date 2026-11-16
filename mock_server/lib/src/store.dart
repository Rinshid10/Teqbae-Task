import 'config.dart';
import 'dates.dart';
import 'models.dart';
import 'scenario.dart';

/// All server state, held in memory. Restarting the server (or calling
/// POST /__mock/reset) empties it again.
class Store {
  Store(this.config, this.now) {
    reset();
  }

  final ServerConfig config;

  /// Injected clock, so tests run at a fixed moment.
  final DateTime Function() now;

  /// The globally selected scenario (POST /__mock/scenario).
  Scenario scenario = Scenario.success;

  /// One record per work date — the map key enforces "one session per day".
  final attendanceByDate = <String, AttendanceRecord>{};

  /// event_id -> the record that event produced. This is the idempotency
  /// table: a retried event is answered from here and changes nothing.
  final recordByEventId = <String, AttendanceRecord>{};

  final leaveRequests = <LeaveRequest>[];

  /// The office geofence centre. Starts at the configured office and can be
  /// moved with POST /__mock/office, so a reviewer anywhere in the world can
  /// test with their real GPS. /employee/me and the geofence check both read
  /// these, so the app and the server always agree.
  late double officeLat;
  late double officeLng;

  /// Yearly allowance per leave type.
  static const leaveTotals = {'CASUAL': 12, 'SICK': 8};

  int _nextId = 1;
  String newId(String prefix) => '${prefix}_${_nextId++}';

  // ---- company time -------------------------------------------------------

  /// Wall-clock time in the company timezone (returned as a UTC-flagged
  /// DateTime whose fields are the local values).
  DateTime companyTime(DateTime instant) =>
      instant.toUtc().add(config.utcOffset);

  /// The company working day an instant falls on.
  String workDateOf(DateTime instant) => formatDate(companyTime(instant));

  /// Today in the company timezone, date-only.
  DateTime today() {
    final t = companyTime(now());
    return DateTime.utc(t.year, t.month, t.day);
  }

  // ---- leave balance ------------------------------------------------------

  /// Days still free to request. Assumption: PENDING requests hold balance
  /// too, otherwise one could submit many requests against the same days.
  int availableLeave(String type) {
    final held = leaveRequests
        .where((r) => r.type == type && r.isActive)
        .fold<int>(0, (sum, r) => sum + r.days);
    return (leaveTotals[type] ?? 0) - held;
  }

  List<Map<String, Object?>> balancesJson() => [
        for (final type in leaveTotals.keys)
          {
            'type': type,
            'total': leaveTotals[type],
            'used': _days(type, 'APPROVED'),
            'pending': _days(type, 'PENDING'),
            'available': availableLeave(type),
          },
      ];

  int _days(String type, String status) => leaveRequests
      .where((r) => r.type == type && r.status == status)
      .fold<int>(0, (sum, r) => sum + r.days);

  // ---- reset --------------------------------------------------------------

  /// Clears everything and puts the office back where the config says. The
  /// server starts with no attendance and no leave
  /// requests: the only fixed data is the employee (/employee/me) and the
  /// yearly leave allowance. Every record is created through the API.
  void reset() {
    scenario = Scenario.success;
    attendanceByDate.clear();
    recordByEventId.clear();
    leaveRequests.clear();
    _nextId = 1;
    officeLat = config.officeLat;
    officeLng = config.officeLng;
  }
}