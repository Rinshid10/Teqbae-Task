import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Centres page content and caps it at 600 wide, so phone layouts do not
/// stretch edge to edge on tablets. Every screen body is wrapped in this.
/// (Not in the original kit list; added so the rule lives in one place.)
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppSpacing.maxContentWidth,
        ),
        child: child,
      ),
    );
  }
}
