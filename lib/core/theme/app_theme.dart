import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text.dart';

/// Spacing constants shared by the widget kit.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;

  /// Horizontal page padding used by every screen in the design.
  static const double page = 20;
  static const double lg = 24;
  static const double xl = 32;

  /// Content never grows wider than this on tablets.
  static const double maxContentWidth = 600;
  static const double cardRadius = 16;
}

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 120);
  static const normal = Duration(milliseconds: 250);
  static const curve = Curves.easeOutCubic;
}

abstract final class AppTheme {
  /// The Figma design defines a light theme only, so the app has one theme.
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.accent,
      onPrimary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
      outline: AppColors.divider,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      // No ink ripples: the design's press feedback is the scale effect.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      textTheme: const TextTheme(
        headlineMedium: AppText.display,
        titleLarge: AppText.title,
        titleMedium: AppText.value,
        bodyLarge: AppText.input,
        bodyMedium: AppText.body,
        bodySmall: AppText.caption,
        labelLarge: AppText.label,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.hairline,
        thickness: 1,
        space: 1,
      ),
      // Short, floating, rounded, one line.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: AppText.labelMedium.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBarrierColor: AppColors.scrim,
        elevation: 0,
      ),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
