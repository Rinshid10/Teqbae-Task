import 'config.dart';
import 'dates.dart';
import 'models.dart';
import 'scenario.dart';

/// All server state, held in memory. Restarting the server (or calling
/// POST /__mock/reset) brings back the same seeded data.
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

  // ---- seed ---------------------------------------------------------------

  /// Clears everything and seeds again. Dates are relative to "today", so
  /// the data always looks recent, and today itself is left empty so a
  /// reviewer can check in straight away.
  void reset() {
    scenario = Scenario.success;
    attendanceByDate.clear();
    recordByEventId.clear();
    leaveRequests.clear();
    _nextId = 1;

    final today = this.today();

    // The 10 most recent weekdays before today.
    var seeded = 0;
    for (var back = 1; seeded < 10; back++) {
      final day = today.subtract(Duration(days: back));
      if (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) {
        continue;
      }
      seeded++;
      // Vary the times a little so the list does not look generated:
      // in between 09:00-09:24, out between 18:00-18:39 (company time).
      final localIn = day.add(Duration(hours: 9, minutes: (back * 7) % 25));
      final localOut = day.add(Duration(hours: 18, minutes: (back * 11) % 40));
      final record = AttendanceRecord(
        id: newId('att'),
        workDate: formatDate(day),
        // company-local -> UTC
        checkInAt: localIn.subtract(config.utcOffset),
        checkOutAt: localOut.subtract(config.utcOffset),
        checkInEventId: 'seed-in-${formatDate(day)}',
        checkOutEventId: 'seed-out-${formatDate(day)}',
      );
      attendanceByDate[record.workDate] = record;
      recordByEventId[record.checkInEventId] = record;
      recordByEventId[record.checkOutEventId!] = record;
    }

    DateTime day(int offset) => today.add(Duration(days: offset));
    leaveRequests.addAll([
      LeaveRequest(
        id: newId('leave'),
        type: 'CASUAL',
        startDate: day(-20),
        endDate: day(-19),
        reason: 'Family function out of town',
        status: 'APPROVED',
        createdAt: now().toUtc().subtract(const Duration(days: 27)),
      ),
      LeaveRequest(
        id: newId('leave'),
        type: 'SICK',
        startDate: day(-35),
        endDate: day(-35),
        reason: 'Dental appointment in the morning',
        status: 'REJECTED',
        createdAt: now().toUtc().subtract(const Duration(days: 36)),
      ),
      LeaveRequest(
        id: newId('leave'),
        type: 'CASUAL',
        startDate: day(10),
        endDate: day(11),
        reason: 'Travelling home for a wedding',
        status: 'PENDING',
        createdAt: now().toUtc().subtract(const Duration(days: 2)),
      ),
    ]);
  }
}
