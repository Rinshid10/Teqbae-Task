import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../core/widgets/pressable_scale.dart';
import '../../../../core/widgets/primary_button.dart';
import '../models/attendance_ui.dart';

/// Opens the "Event details" sheet explaining why the server refused an
/// attendance event.
Future<void> showRejectedEventSheet(
  BuildContext context,
  RejectedEventUi event,
) {
  return showAppSheet<void>(
    context,
    builder: (sheetContext) => RejectedEventContent(
      event: event,
      onClose: () => Navigator.of(sheetContext).pop(),
    ),
  );
}

/// The sheet's content as a plain widget, so it can be tested directly.
class RejectedEventContent extends StatelessWidget {
  const RejectedEventContent({
    super.key,
    required this.event,
    required this.onClose,
  });

  final RejectedEventUi event;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // "EVENT DETAILS" centred, close button on the right.
        SizedBox(
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                AppStrings.eventDetails.toUpperCase(),
                style: AppText.small.copyWith(
                  color: AppColors.textTertiary,
                  letterSpacing: 0.6,
                ),
              ),
              Positioned(
                right: 8,
                child: Semantics(
                  button: true,
                  label: AppStrings.close,
                  child: PressableScale(
                    onTap: onClose,
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(child: AppIcon(AppIcons.close)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Red status icon with a soft halo.
        Center(
          child: Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.dangerFill.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.dangerFill,
                shape: BoxShape.circle,
                boxShadow: AppShadows.flat,
              ),
              child: const AppIcon(AppIcons.errorFilled),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              Text(
                event.title,
                textAlign: TextAlign.center,
                style: AppText.headline,
              ),
              const SizedBox(height: 4),
              const Text(
                AppStrings.rejectedIntro,
                textAlign: TextAlign.center,
                style: AppText.body,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // What was refused, and when.
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.panel,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppShadows.flat,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AppIcon(
                          event.isCheckIn ? AppIcons.login : AppIcons.logout,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child:
                              Text(event.typeLabel, style: AppText.label),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.dangerFill.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.danger,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                AppStrings.declined.toUpperCase(),
                                style: AppText.overline
                                    .copyWith(color: AppColors.dangerStrong),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        const AppIcon(AppIcons.clock),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            event.whenLabel,
                            style: AppText.tabular(AppText.body).copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // The server's reason, verbatim.
              _InfoBox(
                color: AppColors.dangerFill.withValues(alpha: 0.3),
                icon: AppIcons.infoCircle,
                title: AppStrings.rejectedTitle,
                body: event.reason,
              ),
              const SizedBox(height: AppSpacing.sm),
              const _InfoBox(
                color: AppColors.fill,
                icon: AppIcons.shieldCheck,
                title: AppStrings.recordsSafeTitle,
                body: AppStrings.recordsSafeBody,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: PrimaryButton(label: AppStrings.gotIt, onPressed: onClose),
        ),
      ],
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.color,
    required this.icon,
    required this.title,
    required this.body,
  });

  final Color color;
  final String icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(icon),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.label),
                const SizedBox(height: 2),
                Text(body, style: AppText.body.copyWith(height: 22.75 / 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
