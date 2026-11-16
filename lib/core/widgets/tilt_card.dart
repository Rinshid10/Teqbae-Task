import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Tilts its child a few degrees towards the finger while pressed and springs
/// back on release. Used ONLY for the dashboard status card.
class TiltCard extends StatefulWidget {
  const TiltCard({super.key, required this.child, this.maxTiltDegrees = 3});

  final Widget child;
  final double maxTiltDegrees;

  @override
  State<TiltCard> createState() => _TiltCardState();
}

class _TiltCardState extends State<TiltCard> {
  /// Finger position relative to the card centre, each axis in -1..1.
  /// (0, 0) means flat.
  Offset _tilt = Offset.zero;
  bool _down = false;

  void _follow(PointerEvent event) {
    final size = context.size;
    if (size == null || size.isEmpty) return;
    final dx = (event.localPosition.dx / size.width) * 2 - 1;
    final dy = (event.localPosition.dy / size.height) * 2 - 1;
    setState(() {
      _down = true;
      _tilt = Offset(dx.clamp(-1.0, 1.0), dy.clamp(-1.0, 1.0));
    });
  }

  void _release(PointerEvent _) {
    setState(() {
      _down = false;
      _tilt = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxRadians = widget.maxTiltDegrees * math.pi / 180;

    // Listener (raw pointer events) instead of GestureDetector, so the tilt
    // never competes with buttons inside the card or with list scrolling.
    return Listener(
      onPointerDown: _follow,
      onPointerMove: (e) {
        if (_down) _follow(e);
      },
      onPointerUp: _release,
      onPointerCancel: _release,
      // TweenAnimationBuilder animates from wherever the tilt currently is to
      // the new target, so no AnimationController is needed.
      child: TweenAnimationBuilder<Offset>(
        tween: Tween<Offset>(end: _tilt),
        duration: _down ? AppMotion.fast : const Duration(milliseconds: 500),
        // easeOutBack overshoots a little past flat and settles: the "spring".
        curve: _down ? AppMotion.curve : Curves.easeOutBack,
        builder: (context, tilt, child) {
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012) // perspective; without it no depth
              ..rotateX(-tilt.dy * maxRadians)
              ..rotateY(tilt.dx * maxRadians),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
