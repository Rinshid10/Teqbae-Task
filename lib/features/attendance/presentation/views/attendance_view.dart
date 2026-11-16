import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/content_width.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/offline_banner.dart';
import '../../../../core/widgets/pressable_scale.dart';
import '../../../../core/widgets/skeleton_box.dart';
import '../../../../core/widgets/state_builder.dart';
import '../../../sync/presentation/widgets/sync_status_chip.dart';
import '../controllers/attendance_controller.dart';
import '../models/attendance_ui.dart';
import '../widgets/rejected_event_sheet.dart';

/// The Attendance tab: a month of history. This widget only connects the
/// controller's observables to [AttendanceContent].
class AttendanceView extends GetView<AttendanceController> {
  const AttendanceView({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentWidth(
      child: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () => controller.load(refresh: true),
        child: ListView(
          // Always scrollable so pull-to-refresh works on a short page too.
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.xl),
          children: [
            Obx(
              () => StateBuilder<AttendanceScreenData>(
                state: controller.state.value,
                skeleton: const AttendanceSkeleton(),
                onRetry: () => controller.load(refresh: true),
                builder: (context, data) => Obx(
                  () => AttendanceContent(
                    data: data.value,
                    pendingCount: controller.pendingCount.value,
                    onPreviousMonth: controller.previousMonth,
                    onNextMonth: controller.nextMonth,
                    onOpenSync: () => Get.toNamed<void>(AppRoutes.syncCenter),
                    onRejectedTap: (event) =>
                        showRejectedEventSheet(context, event),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The attendance history as a plain widget: data in, callbacks out, no
/// controller lookups. That is what makes it testable with only a data
/// object.
class AttendanceContent extends StatelessWidget {
  const AttendanceContent({
    super.key,
    required this.data,
    required this.pendingCount,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onOpenSync,
    required this.onRejectedTap,
  });

  final AttendanceScreenData data;

  /// Unsent events in the outbox (badge on the sync button).
  final int pendingCount;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onOpenSync;
  final ValueChanged<RejectedEventUi> onRejectedTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _monthSwitcher(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _syncButton(),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (data.offlineMessage != null) ...[
          OfflineBanner(message: data.offlineMessage!),
          const SizedBox(height: AppSpacing.md),
        ],
        _summary(),
        const SizedBox(height: AppSpacing.lg),
        if (data.weeks.isEmpty)
          const AppCard(
            radius: 12,
            shadow: AppShadows.flat,
            child: EmptyView(
              title: AppStrings.noAttendanceMonth,
              message: AppStrings.noAttendanceMessage,
              icon: AppIcons.clock,
            ),
          )
        else
          for (final week in data.weeks) ...[
            _weekHeader(week),
            for (final day in week.days)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _DayRow(day: day, onRejectedTap: onRejectedTap),
              ),
            const SizedBox(height: AppSpacing.md),
          ],
      ],
    );
  }

  Widget _monthSwitcher() {
    Widget arrow(String icon, VoidCallback? onTap, String label) => Semantics(
          button: true,
          enabled: onTap != null,
          label: label,
          child: PressableScale(
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 48,
              child: Center(
                child: Opacity(
                  opacity: onTap == null ? 0.3 : 1,
                  child: AppIcon(icon),
                ),
              ),
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        boxShadow: AppShadows.flat,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          arrow(AppIcons.chevronLeft, onPreviousMonth,
              AppStrings.previousMonth),
          const AppIcon(AppIcons.calendar, color: AppColors.brand),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              data.monthLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.tabular(AppText.title)
                  .copyWith(letterSpacing: -0.45),
            ),
          ),
          arrow(AppIcons.chevronRight, data.canGoNext ? onNextMonth : null,
              AppStrings.nextMonth),
        ],
      ),
    );
  }

  /// Opens the Sync Center; the amber badge counts unsent events.
  Widget _syncButton() {
    final pending = pendingCount > 0;
    return Semantics(
      button: true,
      label: AppStrings.syncCenter,
      child: PressableScale(
        onTap: onOpenSync,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                boxShadow: AppShadows.flat,
              ),
              child: AppIcon(
                AppIcons.sync,
                color: pending ? AppColors.warning : AppColors.brand,
              ),
            ),
            if (pending)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  constraints:
                      const BoxConstraints(minWidth: 20, minHeight: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$pendingCount',
                    style: AppText.tabular(AppText.caption)
                        .copyWith(color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _summary() {
    final summary = data.summary;
    final pending = summary.pendingDays > 0;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _SummaryCard(
              label: AppStrings.summaryPresent,
              icon: AppIcons.checkSmall,
              iconBackground: AppColors.successFill,
              value: summary.presentDays,
              unit: AppStrings.daysWord,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _SummaryCard(
              label: AppStrings.summaryAverage,
              icon: AppIcons.stopwatch,
              iconBackground: AppColors.chip,
              value: summary.averageDaily,
              smallValue: true,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            // Amber only when something is actually waiting.
            child: _SummaryCard(
              label: AppStrings.summaryPending,
              icon: AppIcons.cloud,
              iconBackground:
                  pending ? AppColors.warningDeep : AppColors.chip,
              iconColor: pending ? null : AppColors.textTertiary,
              value: '${summary.pendingDays}',
              unit: AppStrings.logWord(summary.pendingDays),
              highlight: pending,
            ),
          ),
        ],
      ),
    );
  }

  Widget _weekHeader(WeekGroupUi week) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: week.isLatest ? AppColors.brand : AppColors.muted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              week.label,
              style: AppText.label.copyWith(letterSpacing: 0.325),
            ),
          ),
          Text(week.summary, style: AppText.tabular(AppText.caption)),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.icon,
    required this.iconBackground,
    required this.value,
    this.iconColor,
    this.unit,
    this.smallValue = false,
    this.highlight = false,
  });

  final String label;
  final String icon;
  final Color iconBackground;
  final Color? iconColor;
  final String value;
  final String? unit;
  final bool smallValue;

  /// The amber "needs attention" look.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final labelColor =
        highlight ? AppColors.warningText : AppColors.textSecondary;
    final valueColor =
        highlight ? AppColors.warningStrong : AppColors.textPrimary;

    return AppCard(
      radius: 12,
      padding: const EdgeInsets.all(14),
      color: highlight ? AppColors.warningFill : AppColors.surface,
      shadow: AppShadows.flat,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(color: labelColor),
                ),
              ),
              IconBadge(
                icon: icon,
                size: 24,
                background: iconBackground,
                iconColor: iconColor,
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Scales down instead of overflowing in a narrow column.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: AppText.tabular(
                          smallValue ? AppText.title : AppText.headline)
                      .copyWith(color: valueColor),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 4),
                  Text(unit!,
                      style: AppText.caption.copyWith(color: labelColor)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One day: a date tile, the time range with a meta line, and a status
/// chip. Pending days are tinted amber, rejected days red.
class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.onRejectedTap});

  final AttendanceDayUi day;
  final ValueChanged<RejectedEventUi> onRejectedTap;

  @override
  Widget build(BuildContext context) {
    final (tileFill, weekdayColor, numberColor, metaColor, metaIcon) =
        switch (day.sync) {
      SyncChipKind.pending => (
          AppColors.warningFill,
          AppColors.warningText,
          AppColors.warningStrong,
          AppColors.warning,
          AppIcons.cloudOff,
        ),
      SyncChipKind.rejected => (
          AppColors.dangerFill,
          AppColors.danger,
          AppColors.danger,
          AppColors.danger,
          AppIcons.errorCircle,
        ),
      SyncChipKind.synced => (
          AppColors.panel,
          AppColors.textSecondary,
          AppColors.textPrimary,
          AppColors.textSecondary,
          AppIcons.clockSmall,
        ),
    };

    return AppCard(
      radius: 12,
      shadow: AppShadows.flat,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tileFill,
              borderRadius: BorderRadius.circular(8),
            ),
            // The tile is a fixed 40x40, so with a large system font the
            // text is scaled down to fit instead of overflowing it.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    day.weekday,
                    style: AppText.caption.copyWith(
                      height: 1,
                      color: weekdayColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    day.dayNumber,
                    style: AppText.tabular(AppText.title)
                        .copyWith(height: 1, color: numberColor),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day.timeRange,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.tabular(AppText.value)
                      .copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    AppIcon(metaIcon, color: metaColor, size: 11),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        day.metaLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.tabular(AppText.caption)
                            .copyWith(color: metaColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SyncStatusChip(
            kind: day.sync,
            onRejectedTap: day.rejected.isEmpty
                ? null
                : () => onRejectedTap(day.rejected.first),
          ),
        ],
      ),
    );
  }
}

/// Placeholder with the same outline as the loaded screen.
class AttendanceSkeleton extends StatelessWidget {
  const AttendanceSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SkeletonBox(width: 200, height: 56, radius: 999),
            Spacer(),
            SkeletonBox.circle(48),
          ],
        ),
        SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(child: SkeletonBox(height: 76, radius: 12)),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: SkeletonBox(height: 76, radius: 12)),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: SkeletonBox(height: 76, radius: 12)),
          ],
        ),
        SizedBox(height: AppSpacing.lg),
        SkeletonBox(width: 120, height: 16, radius: 4),
        SizedBox(height: AppSpacing.sm),
        SkeletonBox(height: 72, radius: 12),
        SizedBox(height: AppSpacing.sm),
        SkeletonBox(height: 72, radius: 12),
        SizedBox(height: AppSpacing.sm),
        SkeletonBox(height: 72, radius: 12),
      ],
    );
  }
}
