import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/content_width.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/notice_sheet.dart';
import '../../../../core/widgets/pressable_scale.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../attendance/presentation/models/attendance_ui.dart';
import '../../../attendance/presentation/widgets/rejected_event_sheet.dart';
import '../controllers/sync_center_controller.dart';

/// The Sync Center page: what is waiting to be sent, in order, and what
/// happened to recent events.
class SyncCenterView extends GetView<SyncCenterController> {
  const SyncCenterView({super.key});

  /// "Sync Now". Success is a brief snackbar; a failure is explained in a
  /// sheet, together with the reassurance that nothing was lost.
  Future<void> _syncNow(BuildContext context) async {
    final reason = await controller.syncNow();
    if (reason == null || !context.mounted) return;
    await showNoticeSheet(
      context,
      title: AppStrings.syncFailedTitle,
      message: AppStrings.syncFailedBody(reason),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BackHeader(title: AppStrings.syncCenter),
      body: SafeArea(
        child: ContentWidth(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm,
                AppSpacing.page, AppSpacing.xl),
            child: Obx(
              () => SyncCenterBody(
                data: controller.data.value,
                pendingCount: controller.pendingCount.value,
                isSyncing: controller.isSyncing.value,
                isOnline: controller.isOnline.value,
                lastSyncedLabel: controller.lastSyncedLabel.value,
                onSyncNow: () => _syncNow(context),
                onRejectedTap: (event) =>
                    showRejectedEventSheet(context, event),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Plain widget (data in, callbacks out) so the pending state can be
/// widget-tested without a controller.
class SyncCenterBody extends StatelessWidget {
  const SyncCenterBody({
    super.key,
    required this.data,
    required this.pendingCount,
    required this.isSyncing,
    required this.isOnline,
    required this.lastSyncedLabel,
    required this.onSyncNow,
    required this.onRejectedTap,
  });

  final SyncCenterData data;
  final int pendingCount;
  final bool isSyncing;
  final bool isOnline;
  final String lastSyncedLabel;
  final VoidCallback onSyncNow;
  final ValueChanged<RejectedEventUi> onRejectedTap;

  @override
  Widget build(BuildContext context) {
    final pending = pendingCount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Status strip.
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  AppStrings.savedOnDevice,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.labelMedium,
                ),
              ),
              StatusChip(
                label: isOnline ? AppStrings.online : AppStrings.offline,
                tone: isOnline ? ChipTone.success : ChipTone.warning,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Summary card with the Sync Now action.
        AppCard(
          radius: 12,
          shadow: AppShadows.flat,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: pending
                                    ? AppColors.warning
                                    : AppColors.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                pending
                                    ? AppStrings.pendingEvents(pendingCount)
                                    : AppStrings.syncAllDone,
                                style: AppText.title
                                    .copyWith(letterSpacing: -0.45),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const AppIcon(AppIcons.history),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                lastSyncedLabel,
                                style: AppText.tabular(AppText.body),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const IconBadge(
                    icon: AppIcons.monitorCheck,
                    size: 40,
                    background: AppColors.fill,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: isSyncing
                    ? AppStrings.syncing
                    : pending
                        ? AppStrings.syncNowCount(pendingCount)
                        : AppStrings.syncNow,
                icon: AppIcons.sync,
                isLoading: isSyncing, // also blocks a second tap
                onPressed: onSyncNow,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppIcon(AppIcons.autoSync),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      AppStrings.autoSyncHint,
                      textAlign: TextAlign.center,
                      style: AppText.caption
                          .copyWith(color: AppColors.textTertiary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // The queue, in the order it will be sent.
        SectionHeader(
          title: AppStrings.queueTitle,
          trailing: Text(
            AppStrings.queueOrder.toUpperCase(),
            style: AppText.overline.copyWith(color: AppColors.textTertiary),
          ),
        ),
        AppCard(
          radius: 12,
          shadow: AppShadows.flat,
          child: data.queue.isEmpty
              ? const EmptyView(
                  title: AppStrings.queueEmpty,
                  message: AppStrings.queueEmptyMessage,
                  icon: AppIcons.cloudDone,
                )
              : Column(
                  children: [
                    for (var i = 0; i < data.queue.length; i++)
                      _QueueItem(
                        item: data.queue[i],
                        isLast: i == data.queue.length - 1,
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.lg),

        const SectionHeader(title: AppStrings.historyTitleSection),
        AppCard(
          radius: 12,
          padding: EdgeInsets.zero,
          shadow: AppShadows.flat,
          child: data.history.isEmpty
              ? const EmptyView(
                  title: AppStrings.historyEmpty,
                  icon: AppIcons.history,
                )
              : Column(
                  children: [
                    for (var i = 0; i < data.history.length; i++) ...[
                      if (i > 0)
                        const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: AppSpacing.md),
                          child: Divider(),
                        ),
                      _HistoryRow(
                        item: data.history[i],
                        onRejectedTap: onRejectedTap,
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

/// A numbered step in the queue, joined to the next one by a thin rail.
class _QueueItem extends StatelessWidget {
  const _QueueItem({required this.item, required this.isLast});

  final QueueItemUi item;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.warningFill,
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.flat,
                  ),
                  child: Text(
                    item.position,
                    style: AppText.tabular(AppText.label).copyWith(
                      color: AppColors.warningStrong,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                // The rail down to the next number.
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: AppColors.divider),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.panel,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: AppText.label
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const StatusChip(
                          label: AppStrings.pendingSync,
                          tone: ChipTone.warning,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const AppIcon(AppIcons.clock),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.timeLabel,
                            style: AppText.tabular(AppText.body).copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(item.detail, style: AppText.caption),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.idLabel,
                            style: AppText.caption
                                .copyWith(color: AppColors.brand),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item, required this.onRejectedTap});

  final SyncHistoryUi item;
  final ValueChanged<RejectedEventUi> onRejectedTap;

  @override
  Widget build(BuildContext context) {
    final rejected = item.rejected;
    final row = Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          IconBadge(
            icon: rejected == null ? AppIcons.checkCircle : AppIcons.errorCircle,
            size: 36,
            background:
                rejected == null ? AppColors.successFill : AppColors.dangerFill,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.label,
                ),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.tabular(AppText.caption)
                      .copyWith(color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusChip(
            label: rejected == null ? AppStrings.synced : AppStrings.rejected,
            tone: rejected == null ? ChipTone.success : ChipTone.danger,
            onTap: rejected == null ? null : () => onRejectedTap(rejected),
          ),
        ],
      ),
    );

    if (rejected == null) return row;
    // The whole row opens the reason, not just the chip.
    return PressableScale(
      onTap: () => onRejectedTap(rejected),
      pressedScale: 0.99,
      child: row,
    );
  }
}
