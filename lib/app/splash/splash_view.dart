import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/strings/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_icon.dart';
import '../routes/app_routes.dart';

/// The launch screen. It plays one short progress animation and then opens
/// the app. Nothing is loaded here: each tab loads its own data (and shows
/// its own skeleton), so the bar is a brief brand moment, not a real
/// progress measurement — which is why it shows no percentage.
class SplashView extends StatelessWidget {
  const SplashView({super.key, this.onFinished});

  /// Called when the animation ends. Defaults to opening the tabs;
  /// injectable so a widget test can render the screen without navigation.
  final VoidCallback? onFinished;

  static const _duration = Duration(milliseconds: 1400);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Two soft colour glows in opposite corners.
          const Positioned(
            top: -96,
            right: -96,
            child: _Glow(color: Color(0x33A9CBF7)),
          ),
          const Positioned(
            bottom: -96,
            left: -96,
            child: _Glow(color: Color(0x26CFE2FF)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page, vertical: AppSpacing.lg),
              child: Column(
                children: [
                  Opacity(
                    opacity: 0.6,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.panel,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: AppShadows.flat,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                AppStrings.splashBadge.toUpperCase(),
                                style: AppText.caption
                                    .copyWith(letterSpacing: 0.275),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        const AppIcon(AppIcons.splashSync),
                      ],
                    ),
                  ),
                  const Spacer(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Column(
                      children: [
                        const _LogoTile(),
                        const SizedBox(height: AppSpacing.xl),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              AppStrings.splashProduct,
                              style:
                                  AppText.title.copyWith(letterSpacing: -0.45),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        // One pass from empty to full, then into the app.
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: _duration,
                          curve: Curves.easeInOutCubic,
                          onEnd: onFinished ??
                              () => Get.offNamed<void>(AppRoutes.shell),
                          builder: (context, value, _) =>
                              _ProgressBar(value: value),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          AppStrings.splashLoading,
                          textAlign: TextAlign.center,
                          style: AppText.body
                              .copyWith(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.panel,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: AppShadows.flat,
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppIcon(AppIcons.leaf),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  AppStrings.splashHint,
                                  style: AppText.caption,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    AppStrings.appVersion,
                    style: AppText.caption.copyWith(
                      color: AppColors.textTertiary.withValues(alpha: 0.8),
                      letterSpacing: 0.55,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// White tile with the wordmark and a small "pin" below it.
/// (The Figma file's logo layer is empty, so the name is set in type.)
class _LogoTile extends StatelessWidget {
  const _LogoTile();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          width: 150,
          height: 90,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppShadows.sheet,
          ),
          child: Text(
            AppStrings.brandShort,
            style: AppText.display.copyWith(
              color: AppColors.brand,
              letterSpacing: 2,
            ),
          ),
        ),
        Positioned(
          bottom: -8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(999),
              boxShadow: AppShadows.flat,
            ),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.brand,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 6,
        color: AppColors.hairline,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.brand,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}

/// A large, heavily blurred circle of colour.
class _Glow extends StatelessWidget {
  const _Glow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 64, sigmaY: 64),
      child: Container(
        width: 320,
        height: 320,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
