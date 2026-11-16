import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebs_hrms/app/shell/home_shell.dart';
import 'package:rebs_hrms/app/splash/splash_view.dart';
import 'package:rebs_hrms/core/strings/app_strings.dart';
import 'package:rebs_hrms/core/theme/app_theme.dart';
import 'package:rebs_hrms/core/utils/view_state.dart';
import 'package:rebs_hrms/core/widgets/offline_banner.dart';
import 'package:rebs_hrms/core/widgets/skeleton_box.dart';
import 'package:rebs_hrms/core/widgets/status_chip.dart';
import 'package:rebs_hrms/features/attendance/domain/entities/attendance_day.dart';
import 'package:rebs_hrms/features/attendance/presentation/controllers/attendance_controller.dart';
import 'package:rebs_hrms/features/attendance/presentation/models/attendance_ui.dart';
import 'package:rebs_hrms/features/attendance/presentation/models/location_flow.dart';
import 'package:rebs_hrms/features/attendance/presentation/views/attendance_success_view.dart';
import 'package:rebs_hrms/features/attendance/presentation/views/attendance_view.dart';
import 'package:rebs_hrms/features/attendance/presentation/widgets/location_sheet.dart';
import 'package:rebs_hrms/features/attendance/presentation/widgets/rejected_event_sheet.dart';
import 'package:rebs_hrms/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:rebs_hrms/features/dashboard/presentation/views/dashboard_view.dart';
import 'package:rebs_hrms/features/leave/domain/entities/leave.dart';
import 'package:rebs_hrms/features/leave/domain/validators/leave_validator.dart';
import 'package:rebs_hrms/features/leave/presentation/controllers/leave_controller.dart';
import 'package:rebs_hrms/features/leave/presentation/models/leave_ui.dart';
import 'package:rebs_hrms/features/leave/presentation/views/leave_form_view.dart';
import 'package:rebs_hrms/features/leave/presentation/views/leave_review_view.dart';
import 'package:rebs_hrms/features/leave/presentation/views/leave_view.dart';
import 'package:rebs_hrms/features/sync/presentation/controllers/sync_center_controller.dart';
import 'package:rebs_hrms/features/sync/presentation/views/sync_center_view.dart';
import 'package:rebs_hrms/features/sync/presentation/widgets/sync_status_chip.dart';

/// The screens are plain widgets (data in, callbacks out), so these tests
/// need no controllers, no GetX and no database.

// ---- sample data ----------------------------------------------------------

const _rejectedEvent = RejectedEventUi(
  title: 'Check-in not accepted',
  typeLabel: 'Check In',
  isCheckIn: true,
  whenLabel: '12 Nov, 09:15 AM',
  reason: 'A check-in already exists for 2026-11-12.',
);

/// Checked in while offline: the event is in the outbox, not yet synced.
const _pendingDay = AttendanceDayUi(
  workDate: '2026-11-16',
  dateLabel: 'Mon, 16 Nov',
  weekday: 'MON',
  dayNumber: '16',
  timeRange: '09:02 - —',
  checkIn: '09:02 AM',
  checkOut: '—',
  durationLabel: 'In progress',
  metaLabel: 'In progress • Stored locally',
  sync: SyncChipKind.pending,
  rejected: [],
);

const _syncedDay = AttendanceDayUi(
  workDate: '2026-11-13',
  dateLabel: 'Fri, 13 Nov',
  weekday: 'FRI',
  dayNumber: '13',
  timeRange: '09:07 - 18:11',
  checkIn: '09:07 AM',
  checkOut: '06:11 PM',
  durationLabel: '9h 04m',
  metaLabel: '9h 04m net',
  sync: SyncChipKind.synced,
  rejected: [],
);

const _rejectedDay = AttendanceDayUi(
  workDate: '2026-11-12',
  dateLabel: 'Thu, 12 Nov',
  weekday: 'THU',
  dayNumber: '12',
  timeRange: '— - —',
  checkIn: '—',
  checkOut: '—',
  durationLabel: '',
  metaLabel: 'Not accepted',
  sync: SyncChipKind.rejected,
  rejected: [_rejectedEvent],
);

AttendanceScreenData _attendanceData({String? offlineMessage}) =>
    AttendanceScreenData(
      monthLabel: 'Nov 2026',
      canGoNext: false,
      summary: const AttendanceSummaryUi(
          presentDays: '11', averageDaily: '8h 12m', pendingDays: 1),
      weeks: const [
        WeekGroupUi(
          label: 'Week 47',
          summary: '1 day • 0m',
          isLatest: true,
          days: [_pendingDay],
        ),
        WeekGroupUi(
          label: 'Week 46',
          summary: '2 days • 9h 04m',
          isLatest: false,
          days: [_syncedDay, _rejectedDay],
        ),
      ],
      offlineMessage: offlineMessage,
    );

const _dashboardData = DashboardData(
  greeting: 'Good morning, Anjali',
  employeeId: 'EMP-1042',
  department: 'Engineering',
  dateLabel: 'Mon, 16 Nov',
  status: TodayStatus.checkedIn,
  statusLabel: AppStrings.statusCheckedIn,
  statusTone: ChipTone.accent,
  checkIn: '09:02 AM',
  checkOut: '—',
  leaveTotal: '16',
  leaveBreakdown: [(label: 'Casual', value: '8'), (label: 'Sick', value: '8')],
  recent: [_pendingDay, _syncedDay, _rejectedDay],
  offlineMessage: 'Last updated 09:41 AM',
);

const _timer = WorkTimerUi(
  hours: '03',
  minutes: '42',
  seconds: '18s',
  caption: AppStrings.hoursWorkedToday,
);

const _leaveData = LeaveScreenData(
  balances: [
    LeaveBalanceUi(
      type: LeaveType.casual,
      typeLabel: 'Casual',
      available: '6',
      totalLabel: '12 days',
      fraction: 0.5,
      percentLabel: '50%',
    ),
    LeaveBalanceUi(
      type: LeaveType.sick,
      typeLabel: 'Sick',
      available: '4',
      totalLabel: '8 days',
      fraction: 0.5,
      percentLabel: '50%',
    ),
  ],
  filter: LeaveFilter.all,
  counts: {
    LeaveFilter.all: 2,
    LeaveFilter.pending: 1,
    LeaveFilter.approved: 0,
    LeaveFilter.rejected: 1,
  },
  requests: [
    LeaveRequestUi(
      typeLabel: 'Casual',
      daysLabel: '2 days',
      dateRange: '26–27 Nov 2026',
      reason: 'Travelling home for a wedding, which is a long way away',
      statusLabel: 'Pending',
      statusTone: ChipTone.warning,
    ),
    LeaveRequestUi(
      typeLabel: 'Sick',
      daysLabel: '1 day',
      dateRange: '12 Oct 2026',
      reason: 'Dental appointment in the morning',
      statusLabel: 'Rejected',
      statusTone: ChipTone.danger,
    ),
  ],
  offlineMessage: null,
);

const _review = LeaveReviewUi(
  type: LeaveType.casual,
  typeLabel: 'Casual Leave',
  dateRange: '20–22 Nov 2026',
  daysLabel: '3 days',
  balanceAfterLabel: '3 days remaining',
  balanceNowLabel: '(6 available now)',
  remainingFraction: 0.5,
  reason: 'Attending family wedding in Calicut',
);

const _ready = LocationReadyUi(
  title: "You're 45 m from the office",
  subtitle: 'Inside the allowed 200 m radius',
  markerLabel: 'You · 45 m',
  perimeterLabel: '200 m perimeter',
  timeLabel: '09:12 AM',
  accuracyLabel: '±8 m accuracy',
  confirmLabel: AppStrings.confirmCheckIn,
  distanceFraction: 0.225,
);

const _outside = LocationProblemUi(
  kind: ProblemKind.outside,
  pill: AppStrings.outOfRange,
  title: AppStrings.outsideTitle,
  body: "You're 840 m from the office. Check-in is allowed within 200 m.",
  actionLabel: AppStrings.retry,
  action: ProblemAction.retry,
  distanceLabel: '840 m',
  zoneLabel: '200 m zone',
);

const _blocked = LocationProblemUi(
  kind: ProblemKind.blocked,
  pill: AppStrings.pillBlocked,
  title: AppStrings.locationBlockedTitle,
  body: AppStrings.locationDeniedForever,
  actionLabel: AppStrings.actionOpenAppSettings,
  action: ProblemAction.openAppSettings,
  showRetryLink: true,
);

const _syncData = SyncCenterData(
  queue: [
    QueueItemUi(
      position: '1',
      title: 'Check In',
      timeLabel: '16 Nov, 09:12 AM',
      detail: 'Tried 2 times · The server took too long to respond.',
      idLabel: 'ID #920A',
    ),
    QueueItemUi(
      position: '2',
      title: 'Check Out',
      timeLabel: '16 Nov, 06:05 PM',
      detail: 'Waiting for its turn',
      idLabel: 'ID #924F',
    ),
  ],
  history: [
    SyncHistoryUi(
      title: '13 Nov Check-in',
      subtitle: 'Recorded at 09:07 AM',
      rejected: null,
    ),
    SyncHistoryUi(
      title: '12 Nov Check-in',
      subtitle: 'Not accepted by the server',
      rejected: _rejectedEvent,
    ),
  ],
);

// ---- helpers --------------------------------------------------------------

Widget _app(Widget child, {bool scroll = true}) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: scroll
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(20), child: child)
            : child,
      ),
    );

Widget _dashboard(
  ViewState<DashboardData> state, {
  int pendingCount = 1,
  bool isOnline = true,
  VoidCallback? onPrimary,
  VoidCallback? onOpenSync,
}) =>
    DashboardBody(
      state: state,
      initials: 'AM',
      timer: _timer,
      isOnline: isOnline,
      pendingCount: pendingCount,
      syncTitle: pendingCount == 0 ? AppStrings.allSynced : '1 pending',
      syncSubtitle: AppStrings.justNow,
      geoStamp: "You're at the office · 45 m away",
      onRetry: () {},
      onPrimaryAction: onPrimary ?? () {},
      onOpenSync: onOpenSync ?? () {},
      onOpenLeave: () {},
      onSeeAll: () {},
      onOpenDeveloper: () {},
    );

Widget _attendance({
  AttendanceScreenData? data,
  int pendingCount = 1,
  VoidCallback? onOpenSync,
  ValueChanged<RejectedEventUi>? onRejectedTap,
}) =>
    AttendanceContent(
      data: data ?? _attendanceData(),
      pendingCount: pendingCount,
      onPreviousMonth: () {},
      onNextMonth: () {},
      onOpenSync: onOpenSync ?? () {},
      onRejectedTap: onRejectedTap ?? (_) {},
    );

Widget _syncCenter({
  int pendingCount = 2,
  bool isSyncing = false,
  VoidCallback? onSyncNow,
  ValueChanged<RejectedEventUi>? onRejectedTap,
}) =>
    SyncCenterBody(
      data: pendingCount == 0
          ? const SyncCenterData(queue: [], history: [])
          : _syncData,
      pendingCount: pendingCount,
      isSyncing: isSyncing,
      isOnline: true,
      lastSyncedLabel: 'Last synced 10:24 AM',
      onSyncNow: onSyncNow ?? () {},
      onRejectedTap: onRejectedTap ?? (_) {},
    );

Widget _sheet(
  LocationFlowState state, {
  bool isSubmitting = false,
  VoidCallback? onConfirm,
  VoidCallback? onProblemAction,
  VoidCallback? onRetry,
}) =>
    LocationSheetContent(
      state: state,
      isSubmitting: isSubmitting,
      onConfirm: onConfirm ?? () {},
      onCancel: () {},
      onProblemAction: onProblemAction ?? () {},
      onRetry: onRetry ?? () {},
    );

Widget _form({Map<String, String> errors = const {}, String? overlap}) =>
    LeaveFormContent(
      type: LeaveType.casual,
      startDate: DateTime.utc(2026, 11, 20),
      endDate: DateTime.utc(2026, 11, 22),
      reasonController: TextEditingController(text: 'Family function'),
      errors: errors,
      totalBalanceLabel: '10 days in total',
      availableLabel: '6 days available',
      requestedLabel: '3 days requested',
      deductionLabel: 'Taken from your Casual balance (3 remaining)',
      overlapWarning: overlap,
      firstDate: DateTime.utc(2026, 11, 16),
      lastDate: DateTime.utc(2027, 11, 16),
      onTypeChanged: (_) {},
      onStartChanged: (_) {},
      onEndChanged: (_) {},
      onReasonChanged: (_) {},
    );

void _setSize(WidgetTester tester, double width, [double height = 900]) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

const _short = Duration(milliseconds: 400);

void main() {
  group('pending sync state', () {
    testWidgets(
        'Sync Center shows the "Pending Sync" chip and the Sync Now button',
        (tester) async {
      var syncTaps = 0;
      await tester.pumpWidget(_app(_syncCenter(onSyncNow: () => syncTaps++)));
      await tester.pump(_short);

      expect(find.text('2 events waiting to sync'), findsOneWidget);
      // One chip per queued event.
      expect(find.text(AppStrings.pendingSync), findsNWidgets(2));
      expect(find.text('Sync Now (2 Changes)'), findsOneWidget);
      // The queue is shown in sending order, with the retry detail.
      expect(find.text('Check In'), findsOneWidget);
      expect(find.textContaining('Tried 2 times'), findsOneWidget);

      await tester.tap(find.text('Sync Now (2 Changes)'));
      await tester.pump(_short);
      expect(syncTaps, 1);
    });

    testWidgets('while syncing, the button shows progress and ignores taps',
        (tester) async {
      var syncTaps = 0;
      await tester.pumpWidget(
          _app(_syncCenter(isSyncing: true, onSyncNow: () => syncTaps++)));
      await tester.pump(_short);

      expect(find.text(AppStrings.syncing), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text(AppStrings.syncing));
      await tester.pump(_short);
      expect(syncTaps, 0);
    });

    testWidgets('nothing pending: says so and shows an empty queue',
        (tester) async {
      await tester.pumpWidget(_app(_syncCenter(pendingCount: 0)));
      await tester.pump(_short);

      expect(find.text(AppStrings.syncAllDone), findsOneWidget);
      expect(find.text(AppStrings.queueEmpty), findsOneWidget);
      expect(find.text(AppStrings.pendingSync), findsNothing);
    });

    testWidgets('a rejected history row opens its reason', (tester) async {
      RejectedEventUi? opened;
      await tester.pumpWidget(
          _app(_syncCenter(onRejectedTap: (event) => opened = event)));
      await tester.pump(_short);

      await tester.ensureVisible(find.text(AppStrings.rejected));
      await tester.tap(find.text(AppStrings.rejected));
      await tester.pump(_short);
      expect(opened, _rejectedEvent);
    });

    testWidgets('attendance: pending days show the chip and a badge count',
        (tester) async {
      var opened = 0;
      await tester
          .pumpWidget(_app(_attendance(onOpenSync: () => opened++)));
      await tester.pump(_short);

      expect(find.text(AppStrings.pendingSync), findsOneWidget);
      expect(find.text('In progress • Stored locally'), findsOneWidget);
      // The badge on the sync button, and the "Pending" summary card.
      expect(find.text('1'), findsNWidgets(2));

      // The label also carries the badge count, so match by prefix.
      await tester.tap(find.bySemanticsLabel(RegExp(AppStrings.syncCenter)));
      await tester.pump(_short);
      expect(opened, 1);
    });
  });

  group('home', () {
    testWidgets('loading shows the skeleton, not a full-screen spinner',
        (tester) async {
      await tester.pumpWidget(
          _app(_dashboard(const ViewLoading()), scroll: false));

      expect(find.byType(DashboardSkeleton), findsOneWidget);
      expect(find.byType(SkeletonBox), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // The skeleton pulses forever, so pump a fixed time (never settle).
      await tester.pump(const Duration(milliseconds: 900));
      expect(tester.takeException(), isNull);
    });

    testWidgets('error shows the message and a retry button', (tester) async {
      await tester.pumpWidget(_app(
          _dashboard(const ViewError('No internet connection.')),
          scroll: false));
      await tester.pump(_short);

      expect(find.text('No internet connection.'), findsOneWidget);
      expect(find.text(AppStrings.retry), findsOneWidget);
    });

    testWidgets('data shows employee, status, timer, balances and sync state',
        (tester) async {
      _setSize(tester, 390, 1400);
      var primary = 0;
      await tester.pumpWidget(_app(
          _dashboard(const ViewData(_dashboardData),
              onPrimary: () => primary++),
          scroll: false));
      await tester.pump(_short);

      expect(find.text('Good morning, Anjali'), findsOneWidget);
      expect(find.text('CHECKED IN'), findsOneWidget);
      expect(find.text('03'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('18s'), findsOneWidget);
      expect(find.text('1 pending'), findsOneWidget);
      expect(find.byType(OfflineBanner), findsOneWidget);
      expect(find.text("You're at the office · 45 m away"), findsOneWidget);
      // Optimistic UI: already checked in, so the action is Check Out.
      await tester.tap(find.text(AppStrings.checkOut));
      await tester.pump(_short);
      expect(primary, 1);
    });
  });

  group('location sheet', () {
    testWidgets('verifying: Confirm is not available yet', (tester) async {
      var confirms = 0;
      await tester.pumpWidget(_app(
          _sheet(const LocationChecking(), onConfirm: () => confirms++)));
      await tester.pump(_short);

      expect(find.text(AppStrings.verifyingLocation), findsOneWidget);
      expect(find.text(AppStrings.gettingPosition), findsOneWidget);
      await tester.tap(find.text(AppStrings.verifyingShort));
      await tester.pump(_short);
      expect(confirms, 0);
    });

    testWidgets('verified: shows the distance and Confirm works',
        (tester) async {
      var confirms = 0;
      await tester.pumpWidget(_app(
          _sheet(const LocationReady(_ready), onConfirm: () => confirms++)));
      await tester.pump(_short);

      expect(find.text("You're 45 m from the office"), findsOneWidget);
      expect(find.text('±8 m accuracy'), findsOneWidget);
      await tester.ensureVisible(find.text(AppStrings.confirmCheckIn));
      await tester.tap(find.text(AppStrings.confirmCheckIn));
      await tester.pump(_short);
      expect(confirms, 1);
    });

    testWidgets('saving: Confirm shows a spinner and ignores further taps',
        (tester) async {
      var confirms = 0;
      await tester.pumpWidget(_app(_sheet(const LocationReady(_ready),
          isSubmitting: true, onConfirm: () => confirms++)));
      await tester.pump(_short);

      await tester.ensureVisible(find.text(AppStrings.confirmCheckIn));
      await tester.tap(find.text(AppStrings.confirmCheckIn));
      await tester.pump(_short);
      expect(confirms, 0);
    });

    testWidgets('outside: friendly distance message and Try again',
        (tester) async {
      var actions = 0;
      await tester.pumpWidget(_app(_sheet(const LocationProblem(_outside),
          onProblemAction: () => actions++)));
      await tester.pump(_short);

      expect(find.text(AppStrings.outOfRange), findsOneWidget);
      expect(
          find.text(
              "You're 840 m from the office. Check-in is allowed within 200 m."),
          findsOneWidget);
      expect(find.text('840 m'), findsOneWidget);
      await tester.tap(find.text(AppStrings.retry));
      await tester.pump(_short);
      expect(actions, 1);
    });

    testWidgets('permission blocked: Open app settings, plus a retry link',
        (tester) async {
      var actions = 0;
      var retries = 0;
      await tester.pumpWidget(_app(_sheet(const LocationProblem(_blocked),
          onProblemAction: () => actions++, onRetry: () => retries++)));
      await tester.pump(_short);

      await tester.tap(find.text(AppStrings.actionOpenAppSettings));
      await tester.pump(_short);
      await tester.tap(find.text(AppStrings.retry));
      await tester.pump(_short);
      expect(actions, 1);
      expect(retries, 1);
    });
  });

  group('attendance', () {
    testWidgets('a rejected chip reports its event when tapped',
        (tester) async {
      RejectedEventUi? opened;
      await tester.pumpWidget(
          _app(_attendance(onRejectedTap: (event) => opened = event)));
      await tester.pump(_short);

      await tester.ensureVisible(find.text(AppStrings.rejected));
      await tester.tap(find.text(AppStrings.rejected));
      await tester.pump(_short);
      expect(opened, _rejectedEvent);
    });

    testWidgets('the rejected sheet shows the server reason', (tester) async {
      var closed = 0;
      await tester.pumpWidget(_app(RejectedEventContent(
          event: _rejectedEvent, onClose: () => closed++)));
      await tester.pump(_short);

      expect(find.text('Check-in not accepted'), findsOneWidget);
      expect(find.text('A check-in already exists for 2026-11-12.'),
          findsOneWidget);
      await tester.ensureVisible(find.text(AppStrings.gotIt));
      await tester.tap(find.text(AppStrings.gotIt));
      await tester.pump(_short);
      expect(closed, 1);
    });

    testWidgets('the offline banner shows when data is from the cache',
        (tester) async {
      await tester.pumpWidget(_app(_attendance(
          data: _attendanceData(
              offlineMessage: AppStrings.offlineBanner('09:41 AM')))));
      await tester.pump(_short);

      expect(find.byType(OfflineBanner), findsOneWidget);
      expect(find.text('Showing saved data · last updated 09:41 AM'),
          findsOneWidget);
    });

    testWidgets('success page: pending and synced variants', (tester) async {
      const success = AttendanceSuccessUi(
        isCheckIn: true,
        headline: 'Checked in at 09:12 AM',
        subtitle: AppStrings.successCheckInSubtitle,
        distanceLabel: '45 m from the office · ±8 m',
      );
      await tester.pumpWidget(_app(
          AttendanceSuccessBody(
              success: success, isSynced: false, onDone: () {}),
          scroll: false));
      await tester.pump(_short);
      expect(find.text(AppStrings.pendingSync), findsOneWidget);
      expect(find.text(AppStrings.successPendingTitle), findsOneWidget);

      await tester.pumpWidget(_app(
          AttendanceSuccessBody(
              success: success, isSynced: true, onDone: () {}),
          scroll: false));
      await tester.pump(_short);
      expect(find.text(AppStrings.synced), findsOneWidget);
      expect(find.text(AppStrings.successSyncedTitle), findsOneWidget);
    });
  });

  group('leave', () {
    testWidgets('overview: balances, filter chips with counts, requests',
        (tester) async {
      LeaveFilter? chosen;
      await tester.pumpWidget(_app(LeaveContent(
        data: _leaveData,
        isOnline: true,
        onApply: () {},
        onFilter: (filter) => chosen = filter,
      )));
      await tester.pump(_short);

      expect(find.text('50%'), findsNWidgets(2));
      expect(find.text(AppStrings.applyForLeave), findsOneWidget);
      expect(find.text('26–27 Nov 2026'), findsOneWidget);
      await tester.tap(find.text(AppStrings.leaveStatusApproved));
      await tester.pump(_short);
      expect(chosen, LeaveFilter.approved);
    });

    testWidgets('form: inline errors sit under their own fields',
        (tester) async {
      await tester.pumpWidget(_app(_form(errors: const {
        LeaveFields.startDate: AppStrings.leaveStartInPast,
        LeaveFields.endDate: AppStrings.leaveEndBeforeStart,
        LeaveFields.reason: AppStrings.leaveReasonTooShort,
      })));
      await tester.pump(_short);

      expect(find.text(AppStrings.leaveStartInPast), findsOneWidget);
      expect(find.text(AppStrings.leaveEndBeforeStart), findsOneWidget);
      expect(find.text(AppStrings.leaveReasonTooShort), findsOneWidget);
      expect(find.text('3 days requested'), findsOneWidget);
      // The live character counter.
      expect(find.text('15/200'), findsOneWidget);
    });

    testWidgets('form: an overlap warning appears before review',
        (tester) async {
      await tester
          .pumpWidget(_app(_form(overlap: AppStrings.leaveOverlap)));
      await tester.pump(_short);

      expect(find.text(AppStrings.overlapTitle), findsOneWidget);
      expect(find.text(AppStrings.leaveOverlap), findsOneWidget);
    });

    testWidgets('review: Submit is disabled while submitting', (tester) async {
      var submits = 0;
      var edits = 0;
      await tester.pumpWidget(_app(LeaveReviewBody(
        review: _review,
        isSubmitting: true,
        onSubmit: () => submits++,
        onEdit: () => edits++,
      )));
      await tester.pump(_short);

      expect(find.text('"Attending family wedding in Calicut"'),
          findsOneWidget);
      await tester.ensureVisible(find.text(AppStrings.submitRequest));
      await tester.tap(find.text(AppStrings.submitRequest));
      await tester.tap(find.text(AppStrings.editDetails));
      await tester.pump(_short);
      expect(submits, 0);
      expect(edits, 0);
    });
  });

  testWidgets('bottom navigation reports the tapped tab', (tester) async {
    int? selected;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        bottomNavigationBar:
            AppBottomNav(index: 0, onSelected: (i) => selected = i),
      ),
    ));
    await tester.pump(_short);

    await tester.tap(find.text(AppStrings.tabLeave));
    await tester.pump(_short);
    expect(selected, 2);
  });

  testWidgets('splash plays once and then reports it is finished',
      (tester) async {
    var finished = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: SplashView(onFinished: () => finished++),
    ));
    expect(find.text(AppStrings.splashLoading), findsOneWidget);
    expect(finished, 0);

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump();
    expect(finished, 1);
  });

  // Every screen, at the narrowest and widest supported widths. A RenderFlex
  // overflow is reported as an exception, so takeException() == null means
  // "no overflow".
  group('responsive layout', () {
    Widget scrolled(Widget child) => SingleChildScrollView(
        padding: const EdgeInsets.all(20), child: child);

    final screens = <String, Widget Function()>{
      'home': () => _dashboard(const ViewData(_dashboardData)),
      'attendance': () => scrolled(_attendance()),
      'sync center': () => scrolled(_syncCenter()),
      'location sheet (verified)': () =>
          scrolled(_sheet(const LocationReady(_ready))),
      'location sheet (outside)': () =>
          scrolled(_sheet(const LocationProblem(_outside))),
      'rejected sheet': () => scrolled(
          RejectedEventContent(event: _rejectedEvent, onClose: () {})),
      'leave': () => scrolled(LeaveContent(
          data: _leaveData,
          isOnline: false,
          onApply: () {},
          onFilter: (_) {})),
      'leave form': () => scrolled(_form(
            overlap: AppStrings.leaveOverlap,
            errors: const {
              LeaveFields.startDate: AppStrings.leaveStartInPast,
              LeaveFields.endDate: AppStrings.leaveEndBeforeStart,
            },
          )),
      'leave review': () => scrolled(LeaveReviewBody(
          review: _review,
          isSubmitting: false,
          onSubmit: () {},
          onEdit: () {})),
    };

    for (final entry in screens.entries) {
      for (final width in [360.0, 800.0]) {
        testWidgets('${entry.key} at ${width.toInt()}dp has no overflow',
            (tester) async {
          _setSize(tester, width);
          await tester.pumpWidget(_app(entry.value(), scroll: false));
          await tester.pump(_short);
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('${entry.key} with a large system font at 360dp',
          (tester) async {
        _setSize(tester, 360);
        await tester.pumpWidget(MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 900),
            textScaler: TextScaler.linear(1.3),
          ),
          child: _app(entry.value(), scroll: false),
        ));
        await tester.pump(_short);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
