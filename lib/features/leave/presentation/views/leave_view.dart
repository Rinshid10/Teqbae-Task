import 'dart:math' as math;

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
import '../../../../core/widgets/notice_sheet.dart';
import '../../../../core/widgets/offline_banner.dart';
import '../../../../core/widgets/pressable_scale.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/skeleton_box.dart';
import '../../../../core/widgets/state_builder.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/entities/leave.dart';
import '../controllers/leave_controller.dart';
import '../models/leave_ui.dart';

/// The Leave tab: balances, the apply button, filters and the request list.
class LeaveView extends GetView<LeaveController> {
  const LeaveView({super.key});

  /// "Apply for Leave". Leave requests are never queued, so when the app
  /// knows it is offline it says so straight away in a sheet instead of
  /// letting the user fill in a form that cannot be sent.
  Future<void> _apply(BuildContext context) async {
    if (controller.isOffline) {
      final backOnline = await showNoticeSheet(
        context,
        title: AppStrings.offlineSheetTitle,
        message: AppStrings.leaveOfflineBody,
        actionLabel: AppStrings.retry,
        // Asks the server again; the sheet closes only if it answers.
        onAction: controller.recheckConnection,
      );
      if (!backOnline) return;
    }
    await Get.toNamed<void>(AppRoutes.leaveForm);
  }

  @override
  Widget build(BuildContext context) {
    return ContentWidth(
      child: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () => controller.load(refresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.xl),
          children: [
            Obx(
              () => StateBuilder<LeaveScreenData>(
                state: controller.state.value,
                skeleton: const LeaveSkeleton(),
                onRetry: () => controller.load(refresh: true),
                builder: (context, data) => Obx(
                  () => LeaveContent(
                    data: data.value,
                    // Wi-Fi can be on while the server is unreachable, so the
                    // pill also goes "Offline" when the last refresh failed.
                    isOnline: controller.isOnline.value &&
                        data.value.offlineMessage == null,
                    onApply: () => _apply(context),
                    onFilter: controller.setFilter,
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

/// Plain widget (data in, callbacks out) so it can be widget-tested alone.
class LeaveContent extends StatelessWidget {
  const LeaveContent({
    super.key,
    required this.data,
    required this.isOnline,
    required this.onApply,
    required this.onFilter,
  });

  final LeaveScreenData data;
  final bool isOnline;
  final VoidCallback onApply;
  final ValueChanged<LeaveFilter> onFilter;

  static const _filterLabels = {
    LeaveFilter.all: AppStrings.filterAll,
    LeaveFilter.pending: AppStrings.leaveStatusPending,
    LeaveFilter.approved: AppStrings.leaveStatusApproved,
    LeaveFilter.rejected: AppStrings.leaveStatusRejected,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Connection state: leave requests can only be sent while online.
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.fill,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isOnline ? AppColors.success : AppColors.warning,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isOnline ? AppStrings.online : AppStrings.offline,
                  style: AppText.caption,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (data.offlineMessage != null) ...[
          OfflineBanner(message: data.offlineMessage!),
          const SizedBox(height: AppSpacing.md),
        ],
        if (data.balances.isNotEmpty) ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < data.balances.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.md),
                  Expanded(child: _BalanceCard(balance: data.balances[i])),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        PrimaryButton(
          label: AppStrings.applyForLeave,
          icon: AppIcons.plus,
          onPressed: onApply,
        ),
        const SizedBox(height: AppSpacing.lg),
        // Filter chips scroll sideways rather than wrapping.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (final filter in LeaveFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: _FilterChip(
                    label: _filterLabels[filter]!,
                    count: data.counts[filter] ?? 0,
                    selected: filter == data.filter,
                    onTap: () => onFilter(filter),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(title: AppStrings.myRequests),
        if (data.requests.isEmpty)
          const AppCard(
            child: EmptyView(
              title: AppStrings.noLeaveRequests,
              message: AppStrings.noLeaveRequestsMessage,
              icon: AppIcons.calendarCheck,
            ),
          )
        else
          for (final request in data.requests)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _RequestCard(request: request),
            ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});

  final LeaveBalanceUi balance;

  @override
  Widget build(BuildContext context) {
    // Casual is blue, sick is amber, as in the design.
    final isSick = balance.type == LeaveType.sick;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      balance.typeLabel,
                      style: AppText.labelMedium
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                              text: balance.available, style: AppText.title),
                          const TextSpan(text: ' ${AppStrings.daysLeft}'),
                        ],
                      ),
                      style: AppText.tabular(AppText.body),
                    ),
                  ],
                ),
              ),
              _BalanceRing(
                fraction: balance.fraction,
                label: balance.percentLabel,
                color: isSick ? AppColors.warningDeep : AppColors.accent,
                labelColor: isSick ? AppColors.warning : AppColors.brand,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              const Expanded(
                child: Text(
                  AppStrings.totalAllocated,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
              ),
              Text(
                balance.totalLabel,
                style: AppText.tabular(AppText.smallStrong),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 48px progress ring with the percentage in the middle. Drawn with a
/// CustomPainter because the filled share comes from live data.
class _BalanceRing extends StatelessWidget {
  const _BalanceRing({
    required this.fraction,
    required this.label,
    required this.color,
    required this.labelColor,
  });

  final double fraction;
  final String label;
  final Color color;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      // Animates when the balance changes after a request is sent.
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: fraction),
        duration: AppMotion.normal,
        curve: AppMotion.curve,
        builder: (context, value, child) => CustomPaint(
          painter: _RingPainter(fraction: value, color: color),
          child: child,
        ),
        child: Center(
          child: Text(
            label,
            style: AppText.tabular(AppText.caption).copyWith(
              color: labelColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  static const _stroke = 3.82;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - _stroke) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, paint..color = AppColors.fill);
    if (fraction <= 0) return;
    // Starts at 12 o'clock and runs clockwise.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * fraction,
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color;
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.background : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      child: PressableScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.normal,
          curve: AppMotion.curve,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.textPrimary : AppColors.fill,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected ? AppShadows.flat : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: (selected ? AppText.smallStrong : AppText.small)
                    .copyWith(color: foreground),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.divider.withValues(alpha: 0.2)
                      : AppColors.divider,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: AppText.tabular(AppText.caption)
                      .copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});

  final LeaveRequestUi request;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                              text: request.typeLabel, style: AppText.label),
                          const TextSpan(
                            text: '  ·  ',
                            style: TextStyle(color: AppColors.muted),
                          ),
                          TextSpan(text: request.daysLabel),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.small,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      request.dateRange,
                      style: AppText.tabular(AppText.caption),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(label: request.statusLabel, tone: request.statusTone),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const AppIcon(AppIcons.notes),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  request.reason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class LeaveSkeleton extends StatelessWidget {
  const LeaveSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: SkeletonBox(height: 116, radius: 16)),
            SizedBox(width: AppSpacing.md),
            Expanded(child: SkeletonBox(height: 116, radius: 16)),
          ],
        ),
        SizedBox(height: AppSpacing.lg),
        SkeletonBox(height: 52, radius: 999),
        SizedBox(height: AppSpacing.lg),
        SkeletonBox(width: 140, height: 18, radius: 4),
        SizedBox(height: AppSpacing.sm),
        SkeletonBox(height: 92, radius: 16),
        SizedBox(height: AppSpacing.sm),
        SkeletonBox(height: 92, radius: 16),
      ],
    );
  }
}
