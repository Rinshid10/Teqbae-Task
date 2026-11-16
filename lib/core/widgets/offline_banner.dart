import 'package:flutter/material.dart';

import '../strings/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'app_icon.dart';

/// Amber strip telling the user they are looking at saved data.
/// The caller passes the finished sentence (see AppStrings.offlineBanner).
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true, // screen readers announce it when it appears
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.warningFill.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const IconBadge(
              icon: AppIcons.cloudOff,
              size: 32,
              background: AppColors.warningFill,
              iconColor: AppColors.warning,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.offlineTitle.toUpperCase(),
                    style: AppText.smallStrong.copyWith(
                      color: AppColors.warning,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.tabular(AppText.caption),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
