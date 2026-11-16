import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/content_width.dart';
import '../../../../core/widgets/notice_sheet.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/entities/leave.dart';
import '../controllers/leave_controller.dart';
import '../models/leave_ui.dart';

/// Step 2 of applying for leave: check the summary, then send.
class LeaveReviewView extends GetView<LeaveController> {
  const LeaveReviewView({super.key});

  Future<void> _submit(BuildContext context) async {
    // Captured before the await, so no BuildContext is used across it.
    final navigator = Navigator.of(context);
    switch (await controller.submit()) {
      case LeaveSubmitOutcome.sent:
        // Close both the review step and the form, back to the Leave tab.
        navigator.popUntil((route) => route.settings.name == AppRoutes.shell);
      case LeaveSubmitOutcome.fixForm:
        // The errors are now on the form; go back to it.
        navigator.pop();
      case LeaveSubmitOutcome.failed:
        // Stay on this step and say clearly why it was not sent.
        if (!context.mounted) return;
        await showNoticeSheet(
          context,
          title: controller.submitFailedOffline
              ? AppStrings.offlineSheetTitle
              : AppStrings.leaveNotSentTitle,
          message: controller.submitFailedOffline
              ? AppStrings.leaveOfflineBody
              : (controller.submitError ?? AppStrings.unexpectedResponse),
          icon: controller.submitFailedOffline
              ? AppIcons.cloudOff
              : AppIcons.infoCircle,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BackHeader(title: AppStrings.applyLeave),
      body: SafeArea(
        child: ContentWidth(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md,
                AppSpacing.page, AppSpacing.xl),
            child: Obx(() {
              final review = controller.reviewData.value;
              if (review == null) return const SizedBox.shrink();
              return LeaveReviewBody(
                review: review,
                isSubmitting: controller.isSubmitting.value,
                onSubmit: () => _submit(context),
                onEdit: () => Navigator.of(context).maybePop(),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Plain widget (data in, callbacks out).
class LeaveReviewBody extends StatelessWidget {
  const LeaveReviewBody({
    super.key,
    required this.review,
    required this.isSubmitting,
    required this.onSubmit,
    required this.onEdit,
  });

  final LeaveReviewUi review;
  final bool isSubmitting;
  final VoidCallback onSubmit;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.stepTwoOfTwo.toUpperCase(),
                    style: AppText.smallStrong.copyWith(
                      color: AppColors.brand,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(AppStrings.reviewTitle, style: AppText.headline),
                ],
              ),
            ),
            const IconBadge(
              icon: AppIcons.factCheck,
              size: 40,
              background: Color(0x1A0B4A8F), // brand at 10%
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const Text(AppStrings.reviewIntro, style: AppText.body),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          radius: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Leave type highlight.
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.panel,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: AppShadows.flat,
                      ),
                      child: AppIcon(
                        review.type == LeaveType.casual
                            ? AppIcons.umbrella
                            : AppIcons.stethoscope,
                        color: AppColors.brand,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.leaveCategory.toUpperCase(),
                            style: AppText.overline
                                .copyWith(fontWeight: FontWeight.w500),
                          ),
                          Text(review.typeLabel, style: AppText.value),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _DetailRow(
                icon: AppIcons.calendar,
                label: AppStrings.requestedDates,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.dateRange,
                      style: AppText.tabular(AppText.value),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0x1A0B4A8F),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        review.daysLabel,
                        style: AppText.tabular(AppText.caption)
                            .copyWith(color: AppColors.brand),
                      ),
                    ),
                  ],
                ),
              ),
              if (review.balanceAfterLabel != null) ...[
                const SizedBox(height: 14),
                _DetailRow(
                  icon: AppIcons.pieChart,
                  label: AppStrings.balanceAfter,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        children: [
                          Text(
                            review.balanceAfterLabel!,
                            style: AppText.tabular(AppText.value),
                          ),
                          if (review.balanceNowLabel != null)
                            Text(
                              review.balanceNowLabel!,
                              style: AppText.tabular(AppText.caption),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Dark = what is left afterwards, light-blue = this request.
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: SizedBox(
                          height: 6,
                          child: LayoutBuilder(
                            builder: (context, box) => Stack(
                              children: [
                                Container(color: AppColors.successFill),
                                Container(
                                  width:
                                      box.maxWidth * review.remainingFraction,
                                  decoration: BoxDecoration(
                                    color: AppColors.brand,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _DetailRow(
                icon: AppIcons.notes,
                label: AppStrings.reasonForAbsence,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.panel,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '"${review.reason}"',
                    style: AppText.body.copyWith(
                      height: 22.75 / 14,
                      color: AppColors.textPrimary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: AppStrings.submitRequest,
          icon: AppIcons.send,
          isLoading: isSubmitting, // also blocks a second tap
          onPressed: onSubmit,
        ),
        const SizedBox(height: 12),
        SecondaryButton(
          label: AppStrings.editDetails,
          icon: AppIcons.edit,
          onPressed: isSubmitting ? null : onEdit,
        ),
      ],
    );
  }
}

/// Icon circle on the left, a small label and the value on the right.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.child,
  });

  final String icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: IconBadge(
            icon: icon,
            size: 32,
            background: AppColors.fill,
            iconColor: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppText.small),
              const SizedBox(height: 2),
              child,
            ],
          ),
        ),
      ],
    );
  }
}
