import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_theme.dart';

/// Opens a bottom sheet in the app's style: white, top corners rounded 24,
/// a drag handle, and the dim scrim from the theme.
///
/// [isDismissible] false is used while the sheet is doing something that
/// must not be interrupted by a stray tap outside.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true, // let tall sheets size to their content
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    builder: (context) => AppSheet(child: builder(context)),
  );
}

/// The sheet surface itself. Public so it can be rendered directly in a
/// widget test without going through navigation.
class AppSheet extends StatelessWidget {
  const AppSheet({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: AppSpacing.maxContentWidth,
          // Never taller than the screen minus the status bar.
          maxHeight: media.size.height - media.padding.top - 16,
        ),
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: AppShadows.sheet,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle.
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Container(
                    width: 48,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.muted.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                // Scrolls if the content is taller than the sheet may be
                // (small phones, large system font).
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
