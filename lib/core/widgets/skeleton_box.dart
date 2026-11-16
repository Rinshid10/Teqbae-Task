import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Grey placeholder block that gently pulses while content loads.
///
/// The pulse is an AnimatedOpacity that flips its own target each time it
/// finishes (`onEnd`) — no shimmer package, no AnimationController, no Timer.
///
/// Testing note: it animates forever, so widget tests must use `pump()`,
/// not `pumpAndSettle()`, while a skeleton is on screen.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 8,
  });

  /// Null = fill the available width.
  final double? width;
  final double height;
  final double radius;

  /// A round placeholder (avatar, icon tile).
  const SkeletonBox.circle(double size, {super.key})
      : width = size,
        height = size,
        radius = 999;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> {
  bool _dim = false;

  @override
  void initState() {
    super.initState();
    // Start the first fade after the first frame; AnimatedOpacity only
    // animates when its target changes between two builds.
    WidgetsBinding.instance.addPostFrameCallback((_) => _flip());
  }

  void _flip() {
    if (mounted) setState(() => _dim = !_dim);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _dim ? 0.45 : 1,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      onEnd: _flip,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.divider,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}
