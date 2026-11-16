import 'package:flutter/material.dart';

import '../strings/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';
import 'pressable_scale.dart';

/// Round avatar. The API supplies no photo, so it shows the employee's
/// initials; the small blue dot marks "online".
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.initials,
    this.size = 32,
    this.showOnlineDot = false,
  });

  final String initials;
  final double size;
  final bool showOnlineDot;

  @override
  Widget build(BuildContext context) {
    final dot = size >= 48 ? 12.0 : 10.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.chip,
              shape: BoxShape.circle,
              boxShadow: AppShadows.flat,
            ),
            child: Text(
              initials,
              style: (size >= 48 ? AppText.value : AppText.smallStrong)
                  .copyWith(color: AppColors.brand, letterSpacing: 0),
            ),
          ),
          if (showOnlineDot)
            Positioned(
              right: size >= 48 ? 0 : -2,
              bottom: size >= 48 ? 0 : -2,
              child: Container(
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  // The ring in the page colour "cuts" the dot out.
                  border: Border.all(color: AppColors.background, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Top bar of the three main tabs: "REBS •" above the screen title, with the
/// avatar on the right.
class TabHeader extends StatelessWidget implements PreferredSizeWidget {
  const TabHeader({
    super.key,
    required this.title,
    required this.initials,
    this.online = true,
    this.onTitleLongPress,
  });

  final String title;
  final String initials;
  final bool online;

  /// Hidden shortcut for reviewers (opens Developer Settings).
  final VoidCallback? onTitleLongPress;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return _HeaderShell(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: onTitleLongPress,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppStrings.brandShort,
                        style: AppText.smallStrong.copyWith(
                          color: AppColors.brand,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: online ? AppColors.success : AppColors.warning,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.title,
                  ),
                ],
              ),
            ),
          ),
          AppAvatar(initials: initials, showOnlineDot: online),
        ],
      ),
    );
  }
}

/// Top bar of pushed screens: back arrow and a title.
class BackHeader extends StatelessWidget implements PreferredSizeWidget {
  const BackHeader({super.key, required this.title, this.onBack});

  final String title;

  /// Defaults to popping the current route.
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return _HeaderShell(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: MaterialLocalizations.of(context).backButtonTooltip,
            child: PressableScale(
              onTap: onBack ?? () => Navigator.of(context).maybePop(),
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Center(child: AppIcon(AppIcons.arrowBack)),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.title,
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _HeaderShell extends StatelessWidget {
  const _HeaderShell({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        boxShadow: AppShadows.header,
      ),
      // SafeArea keeps the bar below the status bar / notch.
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
            child: Container(height: 64, padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
