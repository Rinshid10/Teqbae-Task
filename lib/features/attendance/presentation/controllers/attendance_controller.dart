import 'dart:async';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/utils/view_state.dart';
import '../../../sync/domain/entities/outbox_event.dart';
import '../../../sync/domain/repositories/outbox_repository.dart';
import '../../../sync/presentation/sync_service.dart';
import '../../domain/entities/attendance_day.dart';
import '../../domain/services/location_service.dart';
import '../../domain/usecases/check_attendance_location.dart';
import '../../domain/usecases/get_attendance_overview.dart';
import '../../domain/usecases/record_attendance_event.dart';
import '../models/attendance_ui.dart';
import '../models/location_flow.dart';

/// The three numbers at the top of the Attendance tab.
class AttendanceSummaryUi {
  const AttendanceSummaryUi({
    required this.presentDays,
    required this.averageDaily,
    required this.pendingDays,
  });

  final String presentDays; // "11"
  final String averageDaily; // "8h 12m" or "—"
  final int pendingDays;
}

/// One calendar week of the selected month.
class WeekGroupUi {
  const WeekGroupUi({
    required this.label,
    required this.summary,
    required this.isLatest,
    required this.days,
  });

  final String label; // "Week 46"
  final String summary; // "3 days • 26h 27m"
  final bool isLatest;
  final List<AttendanceDayUi> days;
}

/// Everything the Attendance tab renders.
class AttendanceScreenData {
  const AttendanceScreenData({
    required this.monthLabel,
    required this.canGoNext,
    required this.summary,
    required this.weeks,
    required this.offlineMessage,
  });

  final String monthLabel; // "Nov 2026"

  /// False on the current month: there is no future attendance to show.
  final bool canGoNext;
  final AttendanceSummaryUi summary;
  final List<WeekGroupUi> weeks;
  final String? offlineMessage;
}

class AttendanceController extends GetxController {
  AttendanceController({
    required GetAttendanceOverview getOverview,
    required CheckAttendanceLocation checkLocation,
    required RecordAttendanceEvent recordEvent,
    required LocationService location,
    required OutboxRepository outbox,
    required SyncService sync,
    required Clock clock,
    required AppFormat format,
    required AttendanceUiMapper mapper,
  })  : _getOverview = getOverview,
        _checkLocation = checkLocation,
        _recordEvent = recordEvent,
        _location = location,
        _outbox = outbox,
        _sync = sync,
        _clock = clock,
        _format = format,
        _mapper = mapper;

  final GetAttendanceOverview _getOverview;
  final CheckAttendanceLocation _checkLocation;
  final RecordAttendanceEvent _recordEvent;
  final LocationService _location;
  final OutboxRepository _outbox;
  final SyncService _sync;
  final Clock _clock;
  final AppFormat _format;
  final AttendanceUiMapper _mapper;

  // ---- history tab --------------------------------------------------------

  final state = Rx<ViewState<AttendanceScreenData>>(const ViewLoading());

  RxBool get isSyncing => _sync.isSyncing;
  RxInt get pendingCount => _sync.pendingCount;

  AttendanceOverview? _overview;

  /// First day of the month being shown (date-only).
  late DateTime _month = _currentMonth();

  /// Result of the last load that used the network. Kept so a local-only
  /// re-render does not make the offline banner flicker away.
  Failure? _refreshError;

  /// Each load gets a number; a slow older load that finishes after a newer
  /// one is ignored instead of overwriting fresher data.
  int _loadId = 0;

  StreamSubscription<void>? _outboxSubscription;
  Worker? _syncWorker;

  // ---- check-in / check-out flow ------------------------------------------

  /// What the location sheet shows. Null when no flow is running.
  final flow = Rxn<LocationFlowState>();

  /// UI-level duplicate-tap lock for the Confirm button.
  final isSubmitting = false.obs;

  /// Filled after a successful check-in/out; drives the confirmation page.
  final lastSuccess = Rxn<AttendanceSuccessUi>();

  /// "You're at the office · 45 m away", after a location check this
  /// session. Null until then: the app never shows a distance it has not
  /// measured.
  final geoStamp = RxnString();

  AttendanceEventType? _flowType;
  LocationCheck? _lastCheck;

  @override
  void onInit() {
    super.onInit();
    // Any outbox change (new event, status update) -> redraw from local data.
    _outboxSubscription = _outbox.changes.listen((_) => _reloadLocal());
    // When a sync run ends the server cache may have been refreshed too.
    _syncWorker = ever<bool>(_sync.isSyncing, (syncing) {
      if (!syncing) _reloadLocal();
    });
    _initialLoad();
  }

  Future<void> _initialLoad() async {
    // Cache first for an instant paint, then the network if that was stale.
    final wasStale = await load(refresh: false);
    if (wasStale) await load(refresh: true);
  }

  DateTime _currentMonth() {
    final today = _clock.today();
    return DateTime.utc(today.year, today.month);
  }

  /// Returns whether the data shown is still stale.
  Future<bool> load({bool refresh = true}) async {
    final id = ++_loadId;
    final overview = await _getOverview(refresh: refresh);
    if (id != _loadId) return false;
    if (refresh || overview.refreshError != null) {
      _refreshError = overview.refreshError;
    }
    _overview = overview;
    _show();
    return overview.isStale;
  }

  Future<void> _reloadLocal() async {
    final id = ++_loadId;
    final overview = await _getOverview.local();
    if (id != _loadId || isClosed) return;
    _overview = overview;
    _show();
  }

  void previousMonth() {
    _month = DateTime.utc(_month.year, _month.month - 1);
    _show();
  }

  void nextMonth() {
    if (!_month.isBefore(_currentMonth())) return;
    _month = DateTime.utc(_month.year, _month.month + 1);
    _show();
  }

  /// Builds the screen from the cached overview and the selected month.
  void _show() {
    final overview = _overview;
    if (overview == null) return;

    // Work dates are yyyy-MM-dd, so a month is a simple prefix match.
    final prefix = Clock.formatDate(_month).substring(0, 7);
    final days = [
      for (final day in overview.history)
        if (day.workDate.startsWith(prefix)) day,
    ];
    final today = overview.today.workDate;

    // Group by ISO week, newest week first (history is already newest first).
    final byWeek = <int, List<AttendanceDay>>{};
    for (final day in days) {
      final week = AppFormat.isoWeek(DateTime.parse(day.workDate));
      byWeek.putIfAbsent(week, () => []).add(day);
    }
    var first = true;
    final weeks = <WeekGroupUi>[];
    for (final entry in byWeek.entries) {
      final worked = entry.value.fold<Duration>(
          Duration.zero, (sum, d) => sum + (d.workedDuration ?? Duration.zero));
      final present = entry.value.where((d) => d.checkIn != null).length;
      weeks.add(WeekGroupUi(
        label: AppStrings.weekLabel(entry.key),
        summary: AppStrings.weekSummary(present, _format.duration(worked)),
        isLatest: first,
        days: [
          for (final d in entry.value)
            _mapper.day(d, isToday: d.workDate == today),
        ],
      ));
      first = false;
    }

    final complete = days.where((d) => d.workedDuration != null).toList();
    final totalWorked = complete.fold<Duration>(
        Duration.zero, (sum, d) => sum + d.workedDuration!);
    final pendingDays = days.where((d) {
      final checkIn = d.checkIn;
      final checkOut = d.checkOut;
      return (checkIn != null && !checkIn.isSynced) ||
          (checkOut != null && !checkOut.isSynced);
    }).length;

    state.value = ViewData(
      AttendanceScreenData(
        monthLabel: _format.monthYear(_month),
        canGoNext: _month.isBefore(_currentMonth()),
        summary: AttendanceSummaryUi(
          presentDays: '${days.where((d) => d.checkIn != null).length}',
          averageDaily: complete.isEmpty
              ? AppStrings.noValue
              : _format.duration(totalWorked ~/ complete.length),
          pendingDays: pendingDays,
        ),
        weeks: weeks,
        offlineMessage: _mapper.offlineMessage(
          refreshFailed: _refreshError != null,
          fetchedAt: overview.fetchedAt,
        ),
      ),
      isStale: overview.isStale,
      isOffline: _refreshError != null,
    );
  }

  // ---- flow ---------------------------------------------------------------

  /// Step 1: the user tapped Check In / Check Out. Decides which of the two
  /// applies and starts verifying the location. The sheet observes [flow].
  Future<void> startFlow() async {
    final overview = await _getOverview.local();
    _overview = overview;
    final type = overview.today.status == TodayStatus.checkedIn
        ? AttendanceEventType.checkOut
        : AttendanceEventType.checkIn;
    await _verifyLocation(type);
  }

  Future<void> _verifyLocation(AttendanceEventType type) async {
    _flowType = type;
    _lastCheck = null;
    flow.value = const LocationChecking();
    HapticFeedback.lightImpact();

    final result = await _checkLocation(type);
    if (isClosed || _flowType != type) return;

    switch (result) {
      case Success(value: final check):
        _lastCheck = check;
        if (check.isInside) {
          geoStamp.value =
              AppStrings.atTheOffice(check.distanceMeters.round());
          flow.value = LocationReady(LocationFlowMapper.ready(
            check,
            type,
            timeLabel: _format.time(check.checkedAt),
          ));
        } else {
          geoStamp.value = null;
          flow.value = LocationProblem(LocationFlowMapper.outside(check, type));
        }
      case Fail(:final failure):
        flow.value = LocationProblem(LocationFlowMapper.failure(failure));
    }
  }

  /// Step 2: the user confirmed. Writes the event to the outbox; from here
  /// it survives an app restart. Returns true when it was recorded.
  Future<bool> confirm() async {
    final type = _flowType;
    final check = _lastCheck;
    if (type == null || check == null) return false;
    if (isSubmitting.value) return false; // duplicate-tap guard

    isSubmitting.value = true;
    HapticFeedback.lightImpact();
    try {
      final result = await _recordEvent(type, position: check.position);
      switch (result) {
        case Success(value: final event):
          lastSuccess.value = AttendanceSuccessUi(
            isCheckIn: type == AttendanceEventType.checkIn,
            headline: type == AttendanceEventType.checkIn
                ? AppStrings.checkedInAt(_format.time(event.occurredAt))
                : AppStrings.checkedOutAt(_format.time(event.occurredAt)),
            subtitle: type == AttendanceEventType.checkIn
                ? AppStrings.successCheckInSubtitle
                : AppStrings.successCheckOutSubtitle,
            distanceLabel: AppStrings.distanceFromOffice(
              check.distanceMeters.round(),
              check.position.accuracy?.round(),
            ),
          );
          flow.value = null;
          // The event is in the outbox, so every screen flips right away
          // with a "Pending Sync" chip — online or not.
          await _reloadLocal();
          // Not awaited: delivery happens in the background.
          unawaited(_sync.syncNow());
          return true;

        case Fail(:final failure):
          flow.value = LocationProblem(LocationFlowMapper.failure(failure));
          // A rule failure can mean the screen was out of date.
          await _reloadLocal();
          return false;
      }
    } finally {
      isSubmitting.value = false;
    }
  }

  /// The main button on a problem state: each problem has its own way out.
  Future<void> onProblemAction() async {
    final current = flow.value;
    if (current is! LocationProblem) return;
    switch (current.problem.action) {
      case ProblemAction.retry:
        final type = _flowType;
        if (type != null) await _verifyLocation(type);
      case ProblemAction.openLocationSettings:
        await _location.openLocationSettings();
      case ProblemAction.openAppSettings:
        await _location.openAppSettings();
      case ProblemAction.close:
        cancelFlow();
    }
  }

  /// "Try again" on a problem whose main action is something else
  /// (e.g. after returning from the settings app).
  Future<void> retryFlow() async {
    final type = _flowType;
    if (type != null) await _verifyLocation(type);
  }

  void cancelFlow() {
    _flowType = null;
    _lastCheck = null;
    flow.value = null;
  }

  @override
  void onClose() {
    _outboxSubscription?.cancel();
    _syncWorker?.dispose();
    super.onClose();
  }
}
