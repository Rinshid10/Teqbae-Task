import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/shell/shell_controller.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/view_state.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/content_width.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/offline_banner.dart';
import '../../../../core/widgets/pressable_scale.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/skeleton_box.dart';
import '../../../../core/widgets/state_builder.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../core/widgets/tilt_card.dart';
import '../../../attendance/domain/entities/attendance_day.dart';
import '../../../attendance/presentation/attendance_flow.dart';
import '../../../attendance/presentation/controllers/attendance_controller.dart';
import '../../../attendance/presentation/models/attendance_ui.dart';
import '../../../attendance/presentation/widgets/rejected_event_sheet.dart';
import '../../../sync/presentation/widgets/sync_status_chip.dart';
import '../controllers/dashboard_controller.dart';

/// The Home tab. Connects the controllers to [DashboardBody].
class DashboardView extends GetView<DashboardController> {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final attendance = Get.find<AttendanceController>();
    final shell = Get.find<ShellController>();

    return ContentWidth(
      child: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () => controller.load(refresh: true),
        child: Obx(
          () => DashboardBody(
            state: controller.state.value,
            initials: controller.initials.value,
            timer: controller.timer.value,
            isOnline: controller.isOnline.value,
            pendingCount: controller.pendingCount.value,
            syncTitle: controller.syncTitle.value,
            syncSubtitle: controller.syncSubtitle.value,
            geoStamp: attendance.geoStamp.value,
            onRetry: () => controller.load(refresh: true),
            onPrimaryAction: () => startAttendanceFlow(context),
            onOpenSync: () => Get.toNamed<void>(AppRoutes.syncCenter),
            onOpenLeave: () => shell.selectTab(2),
            onSeeAll: () => shell.selectTab(1),
            // Reviewer tools exist in debug builds only.
            onOpenDeveloper: kDebugMode
                ? () => Get.toNamed<void>(AppRoutes.developer)
                : null,
          ),
        ),
      ),
    );
  }
}

/// The Home screen as a plain widget (state in, callbacks out), so it can
/// be widget-tested without controllers.
class DashboardBody extends StatelessWidget {
  const DashboardBody({
    super.key,
    required this.state,
    required this.initials,
    required this.timer,
    required this.isOnline,
    required this.pendingCount,
    required this.syncTitle,
    required this.syncSubtitle,
    required this.geoStamp,
    required this.onRetry,
    required this.onPrimaryAction,
    required this.onOpenSync,
    required this.onOpenLeave,
    required this.onSeeAll,
    required this.onOpenDeveloper,
  });

  final ViewState<DashboardData> state;
  final String initials;
  final WorkTimerUi timer;
  final bool isOnline;
  final int pendingCount;
  final String syncTitle;
  final String syncSubtitle;
  final String? geoStamp;
  final VoidCallback onRetry;
  final VoidCallback onPrimaryAction;
  final VoidCallback onOpenSync;
  final VoidCallback onOpenLeave;
  final VoidCallback onSeeAll;

  /// Null hides the reviewer-tools button.
  final VoidCallback? onOpenDeveloper;

  @override
  Widget build(BuildContext context) {
    return ListView(
      // Always scrollable so pull-to-refresh works in every state.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.xl),
      children: [
        StateBuilder<DashboardData>(
          state: state,
          skeleton: const DashboardSkeleton(),
          onRetry: onRetry,
          builder: (context, data) => _content(context, data.value),
        ),
      ],
    );
  }

  Widget _content(BuildContext context, DashboardData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _greeting(data),
        const SizedBox(height: AppSpacing.lg),
        if (data.offlineMessage != null) ...[
          OfflineBanner(message: data.offlineMessage!),
          const SizedBox(height: AppSpacing.md),
        ],
        _TodayCard(
          data: data,
          timer: timer,
          geoStamp: geoStamp,
          onPrimaryAction: onPrimaryAction,
        ),
        const SizedBox(height: AppSpacing.lg + 6), // room for the underlay
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _leaveCard(data)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _syncCard()),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(
          title: AppStrings.recentAttendance,
          trailing: TextLinkButton(
            label: AppStrings.seeAll,
            onPressed: onSeeAll,
            style: AppText.smallStrong,
          ),
        ),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.sm),
          shadow: AppShadows.card,
          child: data.recent.isEmpty
              ? const EmptyView(
                  title: AppStrings.noAttendanceYet,
                  message: AppStrings.noAttendanceMessage,
                  icon: AppIcons.clock,
                )
              : Column(
                  children: [
                    for (var i = 0; i < data.recent.length; i++) ...[
                      if (i > 0) const Divider(),
                      _RecentRow(day: data.recent[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _greeting(DashboardData data) {
    return Row(
      children: [
        AppAvatar(initials: initials, size: 48, showOnlineDot: isOnline),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.greeting,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.title.copyWith(letterSpacing: -0.45),
              ),
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: data.employeeId,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    // Empty when the profile has not been loaded yet.
                    if (data.department.isNotEmpty)
                      TextSpan(text: '  ·  ${data.department}'),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.small,
              ),
            ],
          ),
        ),
        if (onOpenDeveloper != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Semantics(
            button: true,
            label: AppStrings.devTitle,
            child: PressableScale(
              onTap: onOpenDeveloper,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.panel,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.flat,
                ),
                child: const AppIcon(AppIcons.fingerprint),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _leaveCard(DashboardData data) {
    return PressableScale(
      onTap: onOpenLeave,
      child: AppCard(
        shadow: AppShadows.flat,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconBadge(
                  icon: AppIcons.leaveTile,
                  size: 32,
                  radius: 8,
                  background: AppColors.chip,
                ),
                const Spacer(),
                Text(AppStrings.leaveOverline.toUpperCase(),
                    style: AppText.overline.copyWith(
                        fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: data.leaveTotal,
                    style: AppText.title.copyWith(letterSpacing: -0.45),
                  ),
                  const TextSpan(text: ' ${AppStrings.daysWord}'),
                ],
              ),
              style: AppText.body,
            ),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                children: [
                  for (var i = 0; i < data.leaveBreakdown.length; i++) ...[
                    if (i > 0) const TextSpan(text: ' · '),
                    TextSpan(text: '${data.leaveBreakdown[i].label} '),
                    TextSpan(
                      text: data.leaveBreakdown[i].value,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              maxLines: 2,
              style: AppText.caption,
            ),
          ],
        ),
      ),
    );
  }

  Widget _syncCard() {
    final pending = pendingCount > 0;
    // Three looks: offline (amber), online with a backlog (amber), all good.
    final warn = !isOnline || pending;
    final tint = warn ? AppColors.warning : AppColors.success;

    return PressableScale(
      onTap: onOpenSync,
      child: AppCard(
        shadow: AppShadows.flat,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBadge(
                  icon: isOnline ? AppIcons.cloudDone : AppIcons.cloudOff,
                  size: 32,
                  radius: 8,
                  background: warn
                      ? AppColors.warningFill.withValues(alpha: 0.5)
                      : const Color(0x1A1558B0),
                  iconColor: tint,
                ),
                const Spacer(),
                Text(
                  (isOnline ? AppStrings.online : AppStrings.offline)
                      .toUpperCase(),
                  style: AppText.overline.copyWith(color: tint),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              syncTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.label,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration:
                      BoxDecoration(color: tint, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    syncSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.tabular(AppText.caption),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The "today" card: date, shift status, live timer, punch times and the
/// one primary action. A second, slightly smaller card peeks out underneath
/// to give it physical depth, and the whole thing tilts a little on press.
class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.data,
    required this.timer,
    required this.geoStamp,
    required this.onPrimaryAction,
  });

  final DashboardData data;
  final WorkTimerUi timer;
  final String? geoStamp;
  final VoidCallback onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    return TiltCard(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The underlay: inset 8 at the sides, dropped 6 below the card.
          Positioned(
            left: 8,
            right: 8,
            top: 6,
            bottom: -6,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.chip.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppShadows.flat,
              ),
            ),
          ),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.page),
            shadow: AppShadows.raised,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const AppIcon(AppIcons.calendar),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        data.dateLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.label,
                      ),
                    ),
                    StatusChip(
                      label: data.statusLabel,
                      tone: data.statusTone,
                      uppercase: true,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _timer(),
                const SizedBox(height: AppSpacing.lg),
                _punchTimes(),
                const SizedBox(height: AppSpacing.md),
                _action(),
                if (geoStamp != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          geoStamp!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timer() {
    return Column(
      children: [
        // FittedBox shrinks the digits rather than overflowing on a very
        // narrow screen or with a large system font.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(timer.hours, style: AppText.timer),
              const SizedBox(width: 6),
              Text(':', style: AppText.timer.copyWith(color: AppColors.brand)),
              const SizedBox(width: 6),
              Text(timer.minutes, style: AppText.timer),
              if (timer.seconds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 6, bottom: 10),
                  child: Text(
                    timer.seconds,
                    style: AppText.tabular(AppText.small).copyWith(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          timer.caption.toUpperCase(),
          textAlign: TextAlign.center,
          style: AppText.overline.copyWith(
            fontWeight: FontWeight.w500,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _punchTimes() {
    Widget cell(String label, String value) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppText.caption),
            const SizedBox(height: 2),
            Text(value, style: AppText.tabular(AppText.label)),
          ],
        );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(child: cell(AppStrings.checkInLabel, data.checkIn)),
            const VerticalDivider(
                width: 25, thickness: 1, color: AppColors.divider),
            Expanded(child: cell(AppStrings.checkOutLabel, data.checkOut)),
          ],
        ),
      ),
    );
  }

  Widget _action() {
    // AnimatedSwitcher cross-fades Check In -> Check Out -> done text.
    return AnimatedSwitcher(
      duration: AppMotion.normal,
      switchInCurve: AppMotion.curve,
      child: switch (data.status) {
        TodayStatus.notCheckedIn => PrimaryButton(
            key: const ValueKey('check-in'),
            label: AppStrings.checkIn,
            icon: AppIcons.login,
            onPressed: onPrimaryAction,
          ),
        TodayStatus.checkedIn => PrimaryButton(
            key: const ValueKey('check-out'),
            label: AppStrings.checkOut,
            icon: AppIcons.logout,
            onPressed: onPrimaryAction,
          ),
        TodayStatus.checkedOut => const Padding(
            key: ValueKey('done'),
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              AppStrings.doneForToday,
              textAlign: TextAlign.center,
              style: AppText.body,
            ),
          ),
      },
    );
  }
}

/// One line of "Recent attendance": date and times on the left, worked
/// time and sync status on the right.
class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.day});

  final AttendanceDayUi day;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day.dateLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.label,
                ),
                const SizedBox(height: 2),
                Text(
                  day.timeRange,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.tabular(AppText.caption),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Normally one line ("9h 05m  [Synced]"). A Wrap, so on a narrow
          // phone or with a long label the chip drops below the duration
          // instead of overflowing.
          Flexible(
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  day.durationLabel,
                  style: AppText.tabular(AppText.labelMedium),
                ),
                SyncStatusChip(
                  kind: day.sync,
                  onRejectedTap: day.rejected.isEmpty
                      ? null
                      : () =>
                          showRejectedEventSheet(context, day.rejected.first),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder shaped like the loaded Home screen, so nothing jumps when
/// the data arrives.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 112, height: 16, radius: 999),
                    SizedBox(height: 8),
                    SkeletonBox(width: 192, height: 28),
                  ],
                ),
              ),
              SkeletonBox.circle(48),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.page),
        AppCard(
          padding: EdgeInsets.all(AppSpacing.page),
          shadow: AppShadows.flat,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SkeletonBox.circle(32),
                  SizedBox(width: 8),
                  SkeletonBox(width: 96, height: 16, radius: 4),
                  Spacer(),
                  SkeletonBox(width: 96, height: 24, radius: 999),
                ],
              ),
              SizedBox(height: AppSpacing.md),
              _SkeletonTimerPanel(),
              SizedBox(height: AppSpacing.md),
              SkeletonBox(height: 52, radius: 999),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.page),
        Row(
          children: [
            Expanded(child: _SkeletonStatCard(64, 48, 80)),
            SizedBox(width: 12),
            Expanded(child: _SkeletonStatCard(80, 56, 64)),
          ],
        ),
        SizedBox(height: AppSpacing.page),
        AppCard(
          shadow: AppShadows.flat,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 128, height: 16, radius: 4),
              SizedBox(height: AppSpacing.md),
              _SkeletonLogRow(96, 64),
              SizedBox(height: AppSpacing.md),
              _SkeletonLogRow(80, 56),
            ],
          ),
        ),
      ],
    );
  }
}

class _SkeletonTimerPanel extends StatelessWidget {
  const _SkeletonTimerPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          SkeletonBox(width: 160, height: 36),
          SizedBox(height: 8),
          SkeletonBox(width: 128, height: 12, radius: 999),
        ],
      ),
    );
  }
}

class _SkeletonStatCard extends StatelessWidget {
  const _SkeletonStatCard(this.a, this.b, this.c);

  final double a;
  final double b;
  final double c;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      shadow: AppShadows.flat,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: a, height: 12, radius: 999),
          const SizedBox(height: 8),
          SkeletonBox(width: b, height: 24, radius: 6),
          const SizedBox(height: 12),
          SkeletonBox(width: c, height: 10, radius: 999),
        ],
      ),
    );
  }
}

class _SkeletonLogRow extends StatelessWidget {
  const _SkeletonLogRow(this.a, this.b);

  final double a;
  final double b;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SkeletonBox.circle(40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: a, height: 14, radius: 4),
              const SizedBox(height: 6),
              SkeletonBox(width: b, height: 10, radius: 4),
            ],
          ),
        ),
        const SkeletonBox(width: 56, height: 16, radius: 4),
      ],
    );
  }
}
