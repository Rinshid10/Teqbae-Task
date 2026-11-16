import '../../../../core/error/failures.dart';
import '../../../../core/utils/cached.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/result.dart';
import '../../../sync/domain/entities/outbox_event.dart';
import '../../../sync/domain/repositories/outbox_repository.dart';
import '../entities/attendance_day.dart';
import '../entities/attendance_record.dart';
import '../repositories/attendance_repository.dart';
import '../rules/attendance_rules.dart';

/// Today's state and the attendance history, each day being the server
/// record merged with the local outbox.
///
/// It never fails: with no network and an empty cache it still returns the
/// days known from the outbox, so an offline check-in is visible at once.
class GetAttendanceOverview {
  const GetAttendanceOverview({
    required AttendanceRepository attendance,
    required OutboxRepository outbox,
    required Clock clock,
    AttendanceRules rules = const AttendanceRules(),
  })  : _attendance = attendance,
        _outbox = outbox,
        _clock = clock,
        _rules = rules;

  final AttendanceRepository _attendance;
  final OutboxRepository _outbox;
  final Clock _clock;
  final AttendanceRules _rules;

  /// May use the network (see `cachedFetch` for what [refresh] means).
  Future<AttendanceOverview> call({bool refresh = true}) async {
    final result = await _attendance.getRecords(refresh: refresh);
    return switch (result) {
      Success(:final value) => _build(value),
      Fail(:final failure) => _build(null, refreshError: failure),
    };
  }

  /// Local data only, never the network. Screens call this after every
  /// outbox change, which can happen several times a second during a sync.
  Future<AttendanceOverview> local() async =>
      _build(await _attendance.cachedRecords());

  Future<AttendanceOverview> _build(
    Cached<List<AttendanceRecord>>? cached, {
    Failure? refreshError,
  }) async {
    final records = cached?.value ?? const <AttendanceRecord>[];
    final events = await _outbox.all();
    final today = _clock.workDateOf(_clock.nowUtc());

    final recordByDate = {for (final r in records) r.workDate: r};
    final eventsByDate = <String, List<OutboxEvent>>{};
    for (final e in events) {
      eventsByDate.putIfAbsent(e.workDate, () => []).add(e);
    }

    AttendanceDay dayFor(String date) => _rules.buildDay(
        date, recordByDate[date], eventsByDate[date] ?? const []);

    // yyyy-MM-dd sorts correctly as plain text.
    final dates = {...recordByDate.keys, ...eventsByDate.keys}.toList()
      ..sort((a, b) => b.compareTo(a));

    return AttendanceOverview(
      today: dayFor(today),
      history: [
        for (final date in dates)
          if (dayFor(date) case final day when day.hasAnything) day,
      ],
      fetchedAt: cached?.fetchedAt,
      isStale: cached?.isStale ?? true,
      refreshError: refreshError ?? cached?.refreshError,
    );
  }
}
