import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';
import 'pressable_scale.dart';

/// What a chip means, not what colour it is. The widget maps tone -> colour,
/// so callers can never invent a one-off colour.
enum ChipTone { neutral, accent, success, warning, danger }

/// The three colours one tone needs.
typedef _ChipColors = ({Color fill, Color text, Color dot});

/// Small rounded status label with a dot: "Synced", "Pending Sync",
/// "CHECKED IN", "Approved".
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.tone = ChipTone.neutral,
    this.uppercase = false,
    this.onTap,
  });

  final String label;
  final ChipTone tone;

  /// The shift-status pill on Home is upper-case with wide tracking; list
  /// chips are sentence case.
  final bool uppercase;

  /// When set the chip is a button and shows a small chevron
  /// (a "Rejected" chip opens the reason).
  final VoidCallback? onTap;

  static _ChipColors _colors(ChipTone tone) => switch (tone) {
        ChipTone.neutral => (
            fill: AppColors.chip,
            text: AppColors.textSecondary,
            dot: AppColors.textTertiary,
          ),
        ChipTone.accent => (
            fill: const Color(0x1A1558B0), // success at 10%
            text: AppColors.success,
            dot: AppColors.success,
          ),
        ChipTone.success => (
            fill: AppColors.successFill,
            text: AppColors.successText,
            dot: AppColors.success,
          ),
        ChipTone.warning => (
            fill: AppColors.warningFill,
            text: AppColors.warningText,
            dot: AppColors.warning,
          ),
        ChipTone.danger => (
            fill: AppColors.dangerFill,
            text: AppColors.danger,
            dot: AppColors.danger,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final colors = _colors(tone);
    final base = uppercase ? AppText.overline : AppText.caption;

    // AnimatedContainer cross-fades the fill when the tone changes
    // (Pending -> Synced) instead of snapping.
    final chip = AnimatedContainer(
      duration: AppMotion.normal,
      curve: AppMotion.curve,
      padding: EdgeInsets.fromLTRB(10, 5, onTap == null ? 10 : 6, 5),
      decoration: BoxDecoration(
        color: colors.fill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(color: colors.dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              uppercase ? label.toUpperCase() : label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: base.copyWith(
                color: colors.text,
                fontWeight: onTap != null ? FontWeight.w600 : null,
              ),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            AppIcon(AppIcons.chevronRightSmall, color: colors.text, size: 8),
          ],
        ],
      ),
    );

    if (onTap == null) return chip;
    return Semantics(
      button: true,
      child: PressableScale(onTap: onTap, child: chip),
    );
  }
}
