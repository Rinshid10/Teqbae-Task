import 'package:flutter/material.dart';

import '../strings/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';

/// Shown when a request succeeded but there is nothing to list.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    this.title = AppStrings.emptyTitle,
    this.message,
    this.icon = AppIcons.notes,
  });

  final String title;
  final String? message;

  /// AppIcons name.
  final String icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconBadge(
            icon: icon,
            size: 40,
            background: AppColors.fill,
            iconColor: AppColors.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(title, style: AppText.label, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(message!, textAlign: TextAlign.center, style: AppText.caption),
          ],
        ],
      ),
    );
  }
}
