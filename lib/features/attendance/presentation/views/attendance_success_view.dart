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
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/status_chip.dart';
import '../controllers/attendance_controller.dart';
import '../models/location_flow.dart';

/// The confirmation page shown after a check-in or check-out is recorded.
class AttendanceSuccessView extends GetView<AttendanceController> {
  const AttendanceSuccessView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BackHeader(title: AppStrings.tabAttendance),
      body: SafeArea(
        child: ContentWidth(
          child: Obx(() {
            final success = controller.lastSuccess.value;
            if (success == null) return const SizedBox.shrink();
            return AttendanceSuccessBody(
              success: success,
              // The event starts out in the outbox; the pill turns blue by
              // itself when the background sync delivers it.
              isSynced: controller.pendingCount.value == 0,
              onDone: () => Navigator.of(context).maybePop(),
            );
          }),
        ),
      ),
    );
  }
}

/// Plain widget (data in, callback out) so both variants can be tested.
class AttendanceSuccessBody extends StatelessWidget {
  const AttendanceSuccessBody({
    super.key,
    required this.success,
    required this.isSynced,
    required this.onDone,
  });

  final AttendanceSuccessUi success;
  final bool isSynced;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.page, AppSpacing.xl, AppSpacing.page, AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: _SuccessBadge()),
          const SizedBox(height: AppSpacing.lg),
          Text(
            success.headline,
            textAlign: TextAlign.center,
            style: AppText.tabular(AppText.display),
          ),
          const SizedBox(height: 4),
          Text(
            success.subtitle,
            textAlign: TextAlign.center,
            style: AppText.input.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Where the event was recorded, and whether the server has it yet.
          AppCard(
            shadow: AppShadows.card,
            child: Row(
              children: [
                const IconBadge(
                  icon: AppIcons.navigationArrow,
                  size: 36,
                  radius: 12,
                  background: AppColors.fill,
                  iconColor: AppColors.brand,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(AppStrings.office, style: AppText.label),
                      Text(
                        success.distanceLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.tabular(AppText.caption),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusChip(
                  label: isSynced ? AppStrings.synced : AppStrings.pendingSync,
                  tone: isSynced ? ChipTone.success : ChipTone.warning,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Explains the pill in words, especially the offline case.
          AppCard(
            shadow: AppShadows.card,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconBadge(
                  icon: isSynced ? AppIcons.cloudDone : AppIcons.cloudOff,
                  size: 36,
                  radius: 12,
                  background: AppColors.fill,
                  iconColor: isSynced ? AppColors.brand : AppColors.warning,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSynced
                            ? AppStrings.successSyncedTitle
                            : AppStrings.successPendingTitle,
                        style: AppText.label,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isSynced
                            ? AppStrings.successSyncedBody
                            : AppStrings.successPendingBody,
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: AppStrings.backToHome,
            trailingIcon: AppIcons.arrowForward,
            onPressed: onDone,
          ),
        ],
      ),
    );
  }
}

/// The large blue check badge with a soft glow behind it.
class _SuccessBadge extends StatelessWidget {
  const _SuccessBadge();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The glow: a wide, very soft blue shadow.
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x4D9DBFF5),
                  blurRadius: 24,
                  spreadRadius: 12,
                ),
              ],
            ),
          ),
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x471E63C7),
                  offset: Offset(0, 10),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const AppIcon(AppIcons.checkLarge),
          ),
        ],
      ),
    );
  }
}
