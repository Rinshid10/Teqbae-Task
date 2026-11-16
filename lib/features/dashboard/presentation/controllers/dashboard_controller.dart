import 'dart:async';

import 'package:get/get.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/utils/cached.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/utils/view_state.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../attendance/domain/entities/attendance_day.dart';
import '../../../attendance/domain/usecases/get_attendance_overview.dart';
import '../../../attendance/presentation/models/attendance_ui.dart';
import '../../../employee/domain/entities/employee.dart';
import '../../../employee/domain/usecases/get_employee.dart';
import '../../../leave/domain/entities/leave.dart';
import '../../../leave/domain/usecases/get_leave_overview.dart';
import '../../../leave/presentation/models/leave_ui.dart';
import '../../../sync/domain/repositories/outbox_repository.dart';
import '../../../sync/presentation/sync_service.dart';

/// Everything the Home tab renders, as finished strings.
class DashboardData {
  const DashboardData({
    required this.greeting,
    required this.employeeId,
    required this.department,
    required this.dateLabel,
    required this.status,
    required this.statusLabel,
    required this.statusTone,
    required this.checkIn,
    required this.checkOut,
    required this.leaveTotal,
    required this.leaveBreakdown,
    required this.recent,
    required this.offlineMessage,
  });

  final String greeting; // "Good morning, Anjali"
  final String employeeId;
  final String department;
  final String dateLabel; // "Mon, 16 Nov"
  final TodayStatus status;
  final String statusLabel;
  final ChipTone statusTone;
  final String checkIn; // "09:12 AM" or "--:--"
  final String checkOut;

  /// Days left across all leave types, and the same split per type.
  final String leaveTotal;
  final List<({String label, String value})> leaveBreakdown;

  /// The latest five days with activity.
  final List<AttendanceDayUi> recent;
  final String? offlineMessage;
}

/// The big work timer, split so the colon can be coloured separately.
class WorkTimerUi {
  const WorkTimerUi({
    required this.hours,
    required this.minutes,
    required this.seconds,
    required this.caption,
  });

  static const zero = WorkTimerUi(
    hours: '00',
    minutes: '00',
    seconds: '',
    caption: AppStrings.hoursWorkedToday,
  );

  final String hours; // "03"
  final String minutes; // "42"

  /// "18s" while the clock is running, empty when it is not.
  final String seconds;
  final String caption;

  @override
  bool operator ==(Object other) =>
      other is WorkTimerUi &&
      other.hours == hours &&
      other.minutes == minutes &&
      other.seconds == seconds &&
      other.caption == caption;

  @override
  int get hashCode => Object.hash(hours, minutes, seconds, caption);
}

class DashboardController extends GetxController {
  DashboardController({
    required GetEmployee getEmployee,
    required GetAttendanceOverview getAttendance,
    required GetLeaveOverview getLeave,
    required OutboxRepository outbox,
    required SyncService sync,
    required Clock clock,
    required AppFormat format,
    required AttendanceUiMapper attendanceMapper,
  })  : _getEmployee = getEmployee,
        _getAttendance = getAttendance,
        _getLeave = getLeave,
        _outbox = outbox,
        _sync = sync,
        _clock = clock,
        _format = format,
        _attendanceMapper = attendanceMapper;

  final GetEmployee _getEmployee;
  final GetAttendanceOverview _getAttendance;
  final GetLeaveOverview _getLeave;
  final OutboxRepository _outbox;
  final SyncService _sync;
  final Clock _clock;
  final AppFormat _format;
  final AttendanceUiMapper _attendanceMapper;

  static const recentCount = 5;

  final state = Rx<ViewState<DashboardData>>(const ViewLoading());

  /// The live work timer. A separate observable so the once-a-second tick
  /// repaints three Text widgets, not the whole dashboard.
  final timer = WorkTimerUi.zero.obs;

  /// Employee initials for the avatar (the API has no photo). Also read by
  /// the shell for the header avatar.
  final initials = ''.obs;

  // The sync card.
  final syncTitle = AppStrings.allSynced.obs;
  final syncSubtitle = ''.obs;
  /// True only when the device has a connection AND the last refresh
  /// reached the server. Wi-Fi being on does not mean the server answers.
  final isOnline = true.obs;
  RxInt get pendingCount => _sync.pendingCount;

  // The latest pieces, kept so one of them can be refreshed on its own.
  Cached<Employee>? _employee;
  AttendanceOverview? _attendance;
  Cached<LeaveOverview>? _leave;
  bool _refreshFailed = false;

  /// True when the employee has never been loaded and the server cannot be
  /// reached: Home is shown in offline mode without the profile.
  bool _profileMissing = false;
  Worker? _onlineWorker;
  Worker? _deliveredWorker;

  int _loadId = 0;
  int _ticks = 0;
  Timer? _ticker;
  StreamSubscription<void>? _outboxSubscription;
  Worker? _syncWorker;

  @override
  void onInit() {
    super.onInit();
    _outboxSubscription = _outbox.changes.listen((_) => _reloadAttendance());
    _syncWorker = ever<bool>(_sync.isSyncing, (syncing) {
      if (!syncing) _reloadAttendance();
    });
    // When the connection comes back and the screen is showing saved (or
    // missing) data, refresh by itself instead of waiting for a pull.
    _onlineWorker = ever<bool>(_sync.isOnline, (online) {
      if (online && _refreshFailed) load(refresh: true);
    });
    // A sync run just delivered events, so the server is reachable again:
    // refresh the rest of the screen too.
    _deliveredWorker = ever<DateTime?>(_sync.lastSyncedAt, (_) {
      if (_refreshFailed) load(refresh: true);
    });
    // The timer lives here, never in build(). Every second it recomputes
    // the elapsed time from data already in memory (no I/O); once a minute
    // it re-reads local attendance, which also moves "today" forward at
    // company midnight.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateLive();
      if (++_ticks % 60 == 0) _reloadAttendance();
    });
    _initialLoad();
  }

  Future<void> _initialLoad() async {
    // Cache first for an instant paint, then the network if that was stale.
    final wasStale = await load(refresh: false);
    if (wasStale) await load(refresh: true);
  }

  /// Loads all three sources in parallel. Returns whether anything shown is
  /// still stale.
  Future<bool> load({bool refresh = true}) async {
    final id = ++_loadId;

    final employeeFuture = _getEmployee(refresh: refresh);
    final attendanceFuture = _getAttendance(refresh: refresh);
    final leaveFuture = _getLeave(refresh: refresh);
    final employee = await employeeFuture;
    final attendance = await attendanceFuture;
    final leave = await leaveFuture;

    if (id != _loadId) return false; // a newer load has taken over

    switch (employee) {
      case Success(:final value):
        _employee = value;
      case Fail(:final failure):
        // No employee from the server and none saved either (a first launch
        // without a connection). If an earlier load succeeded, that stays
        // on screen instead.
        if (_employee == null) {
          final unreachable =
              failure is NetworkFailure || failure is TimeoutFailure;
          if (!unreachable) {
            // The server answered, but with an error (e.g. 500): that is a
            // real error state with a retry button.
            state.value = ViewError(failure.message);
            return false;
          }
          // The server could not be reached at all. The app must stay
          // usable offline, so Home still opens — without the profile, but
          // with today's card and a working Check In (events are saved to
          // the outbox and synced later).
          _profileMissing = true;
        }
    }
    if (_employee != null) _profileMissing = false;
    _attendance = attendance;
    if (leave case Success(:final value)) _leave = value;

    _refreshFailed = employee is Fail ||
        (employee is Success<Cached<Employee>> &&
            employee.value.refreshError != null) ||
        attendance.refreshError != null ||
        leave is Fail ||
        (leave is Success<Cached<LeaveOverview>> &&
            leave.value.refreshError != null);

    _compose();
    return (_employee?.isStale ?? true) ||
        attendance.isStale ||
        (_leave?.isStale ?? true);
  }

  /// Local-only refresh of the attendance part (outbox change, sync
  /// finished, minute tick). Never touches the network.
  Future<void> _reloadAttendance() async {
    // Nothing on screen yet (still loading, or a real error state).
    if (_employee == null && !_profileMissing) return;
    final overview = await _getAttendance.local();
    if (isClosed) return;
    _attendance = overview;
    _compose();
  }

  void _compose() {
    final employee = _employee?.value;
    final attendance = _attendance;
    if (attendance == null) return;
    if (employee == null && !_profileMissing) return;

    final today = attendance.today;
    final balances = _leave?.value.balances ?? const <LeaveBalance>[];
    // Empty when the profile has never been loaded (offline first launch).
    final names = employee == null
        ? const <String>[]
        : employee.name.trim().split(RegExp(r'\s+'));

    initials.value = names
        .where((n) => n.isNotEmpty)
        .take(2)
        .map((n) => n[0].toUpperCase())
        .join();

    state.value = ViewData(
      DashboardData(
        greeting: _greeting(names.isEmpty ? null : names.first),
        employeeId: employee?.id ?? AppStrings.profileNotLoaded,
        department: employee?.department ?? '',
        dateLabel: _format.workDate(today.workDate),
        status: today.status,
        statusLabel: AttendanceUiMapper.statusLabel(today.status),
        statusTone: AttendanceUiMapper.statusTone(today.status),
        checkIn: _format.time(today.checkIn?.time),
        checkOut: _format.time(today.checkOut?.time),
        // Unknown until the balances have been loaded at least once.
        leaveTotal: balances.isEmpty
            ? AppStrings.noValue
            : '${balances.fold<int>(0, (sum, b) => sum + b.available)}',
        leaveBreakdown: [
          for (final b in balances)
            (label: LeaveUiMapper.typeLabel(b.type), value: '${b.available}'),
        ],
        recent: [
          for (final day in attendance.history.take(recentCount))
            _attendanceMapper.day(day,
                isToday: day.workDate == today.workDate),
        ],
        offlineMessage: _attendanceMapper.offlineMessage(
          refreshFailed: _refreshFailed,
          fetchedAt: _oldestFetch(),
        ),
      ),
      isStale: _refreshFailed,
      isOffline: _refreshFailed,
    );
    _updateLive();
  }

  /// Greeting by the time of day in the COMPANY timezone.
  String _greeting(String? firstName) {
    final hour = _clock.toCompanyTime(_clock.nowUtc()).hour;
    final greeting = hour < 12
        ? AppStrings.goodMorning
        : hour < 17
            ? AppStrings.goodAfternoon
            : AppStrings.goodEvening;
    // No name yet (offline first launch): just "Good morning".
    return firstName == null ? greeting : '$greeting, $firstName';
  }

  /// Recomputes everything that changes with the clock: the work timer and
  /// the sync card's "last synced" line.
  void _updateLive() {
    final today = _attendance?.today;
    final checkIn = today?.checkIn;
    if (today == null || checkIn == null) {
      timer.value = WorkTimerUi.zero;
    } else {
      final checkOut = today.checkOut;
      // Still checked in: count up to now. Checked out: the final total.
      final end = checkOut?.time ?? _clock.nowUtc();
      final elapsed = end.difference(checkIn.time);
      final seconds = elapsed.isNegative ? 0 : elapsed.inSeconds;
      String two(int n) => n.toString().padLeft(2, '0');
      timer.value = WorkTimerUi(
        hours: two(seconds ~/ 3600),
        minutes: two(seconds % 3600 ~/ 60),
        seconds: checkOut == null ? '${two(seconds % 60)}s' : '',
        caption: checkOut == null
            ? AppStrings.hoursWorkedToday
            : AppStrings.totalWorkedToday,
      );
    }

    isOnline.value = _sync.isOnline.value && !_refreshFailed;

    final pending = _sync.pendingCount.value;
    syncTitle.value = pending > 0
        ? AppStrings.pendingShort(pending)
        // "All synced" would be a claim we cannot make while the server is
        // not answering.
        : (_refreshFailed ? AppStrings.nothingWaiting : AppStrings.allSynced);
    final last = _sync.lastSyncedAt.value;
    if (_refreshFailed) {
      // The last refresh failed, so whatever the phone's Wi-Fi says, the
      // server is not answering.
      syncSubtitle.value = AppStrings.serverUnreachable;
    } else if (last == null) {
      syncSubtitle.value =
          pending == 0 ? AppStrings.nothingWaiting : AppStrings.notSyncedYet;
    } else if (_clock.nowUtc().difference(last) < const Duration(minutes: 1)) {
      syncSubtitle.value = AppStrings.justNow;
    } else {
      syncSubtitle.value = AppStrings.lastSyncedAt(_format.time(last));
    }
  }

  /// "Last updated" must not look newer than the oldest piece on screen.
  DateTime? _oldestFetch() {
    final times = [
      _employee?.fetchedAt,
      _attendance?.fetchedAt,
      _leave?.fetchedAt,
    ].whereType<DateTime>().toList();
    if (times.isEmpty) return null;
    return times.reduce((a, b) => a.isBefore(b) ? a : b);
  }

  @override
  void onClose() {
    _ticker?.cancel();
    _onlineWorker?.dispose();
    _deliveredWorker?.dispose();
    _outboxSubscription?.cancel();
    _syncWorker?.dispose();
    super.onClose();
  }
}
