import 'package:flutter/material.dart';

import '../strings/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';
import 'app_sheet.dart';
import 'primary_button.dart';

/// Opens a bottom sheet that tells the user something they must not miss —
/// "You're offline", "Couldn't send your request". Used instead of a
/// snackbar whenever an action the user just asked for could not be done.
///
/// [onAction] (with [actionLabel]) adds a main button such as "Try again".
/// It returns true when the problem is solved; the sheet then closes and
/// [showNoticeSheet] completes with true, so the caller can carry on.
Future<bool> showNoticeSheet(
  BuildContext context, {
  required String title,
  required String message,
  String icon = AppIcons.cloudOff,
  String? actionLabel,
  Future<bool> Function()? onAction,
}) async {
  final solved = await showAppSheet<bool>(
    context,
    builder: (sheetContext) => NoticeSheetContent(
      title: title,
      message: message,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
      onClose: (result) => Navigator.of(sheetContext).pop(result),
    ),
  );
  return solved ?? false;
}

/// The sheet's content. Public (and plain) so it can be widget-tested.
class NoticeSheetContent extends StatefulWidget {
  const NoticeSheetContent({
    super.key,
    required this.title,
    required this.message,
    required this.onClose,
    this.icon = AppIcons.cloudOff,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String icon;
  final String? actionLabel;
  final Future<bool> Function()? onAction;

  /// Called with true when the action solved the problem, false otherwise.
  final ValueChanged<bool> onClose;

  @override
  State<NoticeSheetContent> createState() => _NoticeSheetContentState();
}

class _NoticeSheetContentState extends State<NoticeSheetContent> {
  /// True while the action is running (e.g. re-checking the connection), so
  /// the button shows a spinner and cannot be tapped twice.
  bool _busy = false;

  Future<void> _runAction() async {
    if (_busy) return;
    setState(() => _busy = true);
    final solved = await widget.onAction!();
    if (!mounted) return;
    setState(() => _busy = false);
    // Still not solved: the sheet stays open with the same message.
    if (solved) widget.onClose(true);
  }

  @override
  Widget build(BuildContext context) {
    final hasAction = widget.onAction != null && widget.actionLabel != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Amber icon with a soft halo.
          Center(
            child: Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.warningFill.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: IconBadge(
                icon: widget.icon,
                size: 48,
                background: AppColors.warningFill,
                iconColor: AppColors.warning,
                iconSize: 18,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // liveRegion: screen readers read the message when it appears.
          Semantics(
            liveRegion: true,
            child: Column(
              children: [
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: AppText.headline,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: AppText.body,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (hasAction) ...[
            PrimaryButton(
              label: widget.actionLabel!,
              icon: AppIcons.refresh,
              isLoading: _busy,
              onPressed: _runAction,
            ),
            const SizedBox(height: 4),
            TextLinkButton(
              label: AppStrings.close,
              color: AppColors.textSecondary,
              style: AppText.input,
              expand: true,
              onPressed: _busy ? null : () => widget.onClose(false),
            ),
          ] else
            PrimaryButton(
              label: AppStrings.gotIt,
              onPressed: () => widget.onClose(false),
            ),
        ],
      ),
    );
  }
}
