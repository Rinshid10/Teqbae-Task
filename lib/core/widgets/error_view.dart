import 'package:flutter/material.dart';

import '../strings/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_theme.dart';
import 'app_card.dart';
import 'app_icon.dart';
import 'primary_button.dart';

/// Shown when loading failed and there is no cached data to fall back on.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const IconBadge(
            icon: AppIcons.errorFilled,
            size: 48,
            background: AppColors.dangerFill,
          ),
          const SizedBox(height: 12),
          const Text(
            AppStrings.errorTitle,
            style: AppText.title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center, style: AppText.body),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: AppStrings.retry,
              icon: AppIcons.refresh,
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}
