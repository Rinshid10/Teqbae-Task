import 'package:flutter/painting.dart';

import 'app_colors.dart';

/// The type scale from the Figma file. Names say what a style is for; the
/// comment gives size / line-height.
///
/// No font family is set, so every device uses its own system font
/// (Roboto on Android, San Francisco on iOS). Sizes, weights and spacing
/// still follow the Figma type scale.
abstract final class AppText {
  /// 28/34 — the one big headline (check-in confirmation).
  static const display = TextStyle(
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.7,
    color: AppColors.textPrimary,
  );

  /// 22/28 — sheet titles and large metric numbers.
  static const headline = TextStyle(
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.33,
    color: AppColors.textPrimary,
  );

  /// 18/24 — screen titles and section headings.
  static const title = TextStyle(
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.18,
    color: AppColors.textPrimary,
  );

  /// 15/21 semibold — button labels and important values.
  static const value = TextStyle(
    fontSize: 15,
    height: 21 / 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// 15/21 regular — input text and list row titles.
  static const input = TextStyle(
    fontSize: 15,
    height: 21 / 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  /// 14/20 — body copy.
  static const body = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// 13/18 semibold — row titles.
  static const label = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// 13/18 medium — text links and secondary row titles.
  static const labelMedium = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  /// 12/16 medium — small labels.
  static const small = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.12,
    color: AppColors.textSecondary,
  );

  /// 12/16 semibold — pill labels and small values.
  static const smallStrong = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.12,
    color: AppColors.textPrimary,
  );

  /// 11/14 medium — captions and meta lines.
  static const caption = TextStyle(
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.22,
    color: AppColors.textSecondary,
  );

  /// 11/14 semibold, wide tracking — UPPERCASE overlines and status pills.
  /// The caller upper-cases the text.
  static const overline = TextStyle(
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.55,
    color: AppColors.textSecondary,
  );

  /// 44/55 bold — the live work timer. Tabular figures so the digits do
  /// not shift sideways as they tick.
  static const timer = TextStyle(
    fontSize: 44,
    height: 55 / 44,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.1,
    fontFeatures: [FontFeature.tabularFigures()],
    color: AppColors.textPrimary,
  );

  /// 11/14 — small technical values.
  static const monoCaption = TextStyle(
    fontSize: 11,
    height: 14 / 11,
    letterSpacing: 0.22,
    color: AppColors.textTertiary,
  );

  /// Makes every digit the same width, so a column of times lines up.
  static TextStyle tabular(TextStyle style) =>
      style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}
