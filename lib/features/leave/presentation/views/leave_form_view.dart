import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_date_picker_field.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/content_width.dart';
import '../../../../core/widgets/pressable_scale.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/entities/leave.dart';
import '../../domain/validators/leave_validator.dart';
import '../controllers/leave_controller.dart';

/// Step 1 of applying for leave: the form. "Review Request" validates and
/// moves on to the review step.
class LeaveFormView extends GetView<LeaveController> {
  const LeaveFormView({super.key});

  Future<void> _review(BuildContext context) async {
    FocusScope.of(context).unfocus();
    if (await controller.review()) {
      await Get.toNamed<void>(AppRoutes.leaveReview);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BackHeader(title: AppStrings.applyLeave),
      body: SafeArea(
        child: ContentWidth(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.page,
                      AppSpacing.md, AppSpacing.page, AppSpacing.lg),
                  child: Obx(
                    () => LeaveFormContent(
                      type: controller.type.value,
                      startDate: controller.startDate.value,
                      endDate: controller.endDate.value,
                      reasonController: controller.reasonController,
                      // Copied so Obx registers a read of the observable map.
                      errors: Map.of(controller.errors),
                      totalBalanceLabel: controller.totalBalanceLabel.value,
                      availableLabel: controller.availableLabel.value,
                      requestedLabel: controller.requestedLabel.value,
                      deductionLabel: controller.deductionLabel.value,
                      overlapWarning: controller.overlapWarning.value,
                      firstDate: controller.firstSelectableDate,
                      lastDate: controller.lastSelectableDate,
                      onTypeChanged: controller.setType,
                      onStartChanged: controller.setStartDate,
                      onEndChanged: controller.setEndDate,
                      onReasonChanged: controller.onReasonChanged,
                    ),
                  ),
                ),
              ),
              // The action stays pinned above the keyboard / bottom edge.
              Container(
                color: AppColors.background,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: PrimaryButton(
                  label: AppStrings.reviewRequest,
                  trailingIcon: AppIcons.arrowForward,
                  onPressed: () => _review(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The form as a plain widget: values in, callbacks out.
class LeaveFormContent extends StatelessWidget {
  const LeaveFormContent({
    super.key,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.reasonController,
    required this.errors,
    required this.totalBalanceLabel,
    required this.availableLabel,
    required this.requestedLabel,
    required this.deductionLabel,
    required this.overlapWarning,
    required this.firstDate,
    required this.lastDate,
    required this.onTypeChanged,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onReasonChanged,
  });

  final LeaveType type;
  final DateTime? startDate;
  final DateTime? endDate;
  final TextEditingController reasonController;
  final Map<String, String> errors;
  final String totalBalanceLabel;
  final String availableLabel;
  final String requestedLabel;
  final String deductionLabel;
  final String? overlapWarning;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<LeaveType> onTypeChanged;
  final ValueChanged<DateTime> onStartChanged;
  final ValueChanged<DateTime> onEndChanged;
  final ValueChanged<String> onReasonChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (totalBalanceLabel.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.panel,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const AppIcon(AppIcons.leaf),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    AppStrings.leaveBalanceStrip,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.small,
                  ),
                ),
                Text(
                  totalBalanceLabel,
                  style: AppText.tabular(AppText.smallStrong)
                      .copyWith(color: AppColors.brand),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        // ---- leave type --------------------------------------------------
        _FieldLabel(
          AppStrings.leaveTypeLabel,
          trailing: availableLabel.isEmpty
              ? null
              : Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.successFill,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    availableLabel,
                    style: AppText.tabular(AppText.caption).copyWith(
                      color: AppColors.successText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        ),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.fill,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: _TypeSegment(
                  label: AppStrings.leaveCasual,
                  icon: AppIcons.umbrella,
                  selected: type == LeaveType.casual,
                  onTap: () => onTypeChanged(LeaveType.casual),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _TypeSegment(
                  label: AppStrings.leaveSick,
                  icon: AppIcons.stethoscope,
                  selected: type == LeaveType.sick,
                  onTap: () => onTypeChanged(LeaveType.sick),
                ),
              ),
            ],
          ),
        ),
        if (errors[LeaveFields.type] != null) _error(errors[LeaveFields.type]!),
        const SizedBox(height: AppSpacing.lg),

        // ---- dates -------------------------------------------------------
        const _FieldLabel(AppStrings.durationLabel),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppDatePickerField(
                label: AppStrings.leaveStartLabel,
                value: startDate,
                firstDate: firstDate,
                lastDate: lastDate,
                icon: AppIcons.calendarStart,
                errorText: errors[LeaveFields.startDate],
                onChanged: onStartChanged,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppDatePickerField(
                label: AppStrings.leaveEndLabel,
                value: endDate,
                firstDate: firstDate,
                lastDate: lastDate,
                icon: AppIcons.calendarEnd,
                errorText: errors[LeaveFields.endDate],
                onChanged: onEndChanged,
              ),
            ),
          ],
        ),

        // "3 days requested" appears once both dates are chosen.
        AnimatedSize(
          duration: AppMotion.normal,
          curve: AppMotion.curve,
          alignment: Alignment.topCenter,
          child: requestedLabel.isEmpty
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.lg),
                  child: _DurationBadge(
                    title: requestedLabel,
                    subtitle: deductionLabel,
                  ),
                ),
        ),
        AnimatedSize(
          duration: AppMotion.normal,
          curve: AppMotion.curve,
          alignment: Alignment.topCenter,
          child: overlapWarning == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: _WarningCard(message: overlapWarning!),
                ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ---- reason ------------------------------------------------------
        const _FieldLabel(AppStrings.leaveReasonLabel),
        AppTextField(
          controller: reasonController,
          hint: AppStrings.leaveReasonPlaceholder,
          helperText: AppStrings.leaveReasonHint,
          errorText: errors[LeaveFields.reason],
          maxLines: 3,
          maxLength: LeaveController.maxReasonLength,
          onChanged: onReasonChanged,
        ),
      ],
    );
  }

  Widget _error(String message) => Padding(
        padding: const EdgeInsets.only(top: 6, left: 4),
        child: Text(
          message,
          style: AppText.caption.copyWith(color: AppColors.danger),
        ),
      );
}

/// Upper-case label above a form control, with an optional badge on the right.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.small.copyWith(color: AppColors.textTertiary),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _TypeSegment extends StatelessWidget {
  const _TypeSegment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.brand : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      child: PressableScale(
        onTap: onTap,
        // The white "thumb" fades in under the selected segment.
        child: AnimatedContainer(
          duration: AppMotion.normal,
          curve: AppMotion.curve,
          height: 48,
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : AppColors.fill,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected ? AppShadows.flat : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(icon, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.labelMedium.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DurationBadge extends StatelessWidget {
  const _DurationBadge({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x1A0B4A8F), // brand at 10%
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const IconBadge(
            icon: AppIcons.calendarCheck,
            size: 36,
            radius: 12,
            background: AppColors.brand,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.tabular(AppText.label)
                      .copyWith(color: AppColors.brand),
                ),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: AppText.tabular(AppText.caption)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.warningFill.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppIcon(AppIcons.infoCircle, color: AppColors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.overlapTitle,
                    style:
                        AppText.label.copyWith(color: AppColors.warningStrong),
                  ),
                  const SizedBox(height: 1),
                  Text(message, style: AppText.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
