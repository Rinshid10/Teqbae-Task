import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';
import 'pressable_scale.dart';

/// The blue pill used for the main action on a screen.
///
/// It reads as slightly raised: a blue glow underneath and a thin light
/// line along the top edge. Pressing scales it to 0.97 and shrinks the glow.
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
  });

  final String label;

  /// Null renders the button disabled.
  final VoidCallback? onPressed;

  /// AppIcons name shown before the label.
  final String? icon;

  /// AppIcons name shown after the label (e.g. a forward arrow).
  final String? trailingIcon;

  /// Shows an inline spinner and ignores taps, so a slow request can never
  /// be submitted twice from the UI.
  final bool isLoading;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.isLoading;

    return Semantics(
      button: true,
      enabled: enabled,
      child: PressableScale(
        onTap: enabled ? widget.onPressed : null,
        onPressedChanged: (value) => setState(() => _pressed = value),
        child: AnimatedOpacity(
          // A loading button stays fully visible; only a disabled one fades.
          opacity: widget.onPressed == null ? 0.45 : 1,
          duration: AppMotion.normal,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.curve,
            height: 52,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(999),
              boxShadow:
                  _pressed ? AppShadows.buttonPressed : AppShadows.button,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // The 1.5px light line along the top edge.
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ColoredBox(
                    color: Color(0x40FFFFFF),
                    child: SizedBox(height: 1.5),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: AppMotion.normal,
                        child: _leading(),
                      ),
                      // Flexible + ellipsis: never overflows on a narrow phone.
                      Flexible(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.value.copyWith(color: Colors.white),
                        ),
                      ),
                      if (widget.trailingIcon != null && !widget.isLoading)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: AppIcon(
                            widget.trailingIcon!,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _leading() {
    if (widget.isLoading) {
      return const Padding(
        key: ValueKey('spinner'),
        padding: EdgeInsets.only(right: 10),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        ),
      );
    }
    if (widget.icon != null) {
      return Padding(
        key: const ValueKey('icon'),
        padding: const EdgeInsets.only(right: 8),
        child: AppIcon(widget.icon!, color: Colors.white),
      );
    }
    return const SizedBox.shrink(key: ValueKey('none'));
  }
}

/// White pill for the second choice next to a primary button
/// ("Edit Details", "Reset").
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = AppColors.textPrimary,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? icon;

  /// Label and icon colour; red for destructive actions.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: PressableScale(
        onTap: onPressed,
        child: Container(
          height: 48,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            boxShadow: AppShadows.flat,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                AppIcon(icon!, color: color),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.value.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A text-only action in brand blue ("Cancel", "See all", "Open settings").
class TextLinkButton extends StatelessWidget {
  const TextLinkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.color = AppColors.brand,
    this.expand = false,
    this.style = AppText.labelMedium,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? icon;
  final String? trailingIcon;
  final Color color;

  /// True makes it a full-width 48px row (sheet footers).
  final bool expand;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          AppIcon(icon!, color: color),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style.copyWith(color: color),
          ),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: 6),
          AppIcon(trailingIcon!, color: color),
        ],
      ],
    );

    return Semantics(
      button: true,
      child: PressableScale(
        onTap: onPressed,
        child: Container(
          // 44px minimum keeps the tap target comfortable.
          constraints: const BoxConstraints(minHeight: 44),
          width: expand ? double.infinity : null,
          height: expand ? 48 : null,
          alignment: expand ? Alignment.center : null,
          padding: EdgeInsets.symmetric(horizontal: expand ? 16 : 4),
          child: expand ? content : Center(widthFactor: 1, child: content),
        ),
      ),
    );
  }
}
