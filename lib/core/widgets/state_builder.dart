import 'package:flutter/material.dart';

import '../strings/app_strings.dart';
import '../theme/app_theme.dart';
import '../utils/view_state.dart';
import 'empty_view.dart';
import 'error_view.dart';
import 'skeleton_box.dart';

/// Renders a [ViewState]: skeleton, empty view, error view or the data.
/// Every screen uses this, so the four states look and animate the same
/// everywhere and no view writes its own loading/error branching.
class StateBuilder<T> extends StatelessWidget {
  const StateBuilder({
    super.key,
    required this.state,
    required this.builder,
    this.skeleton,
    this.onRetry,
    this.emptyTitle = AppStrings.emptyTitle,
    this.emptyMessage,
  });

  final ViewState<T> state;

  /// Builds the data UI. Receives the whole ViewData so it can also read
  /// `isStale` / `isOffline`.
  final Widget Function(BuildContext context, ViewData<T> data) builder;

  /// Placeholder shaped like the real content. Falls back to three bars.
  final Widget? skeleton;
  final VoidCallback? onRetry;
  final String emptyTitle;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    // The switch is exhaustive because ViewState is sealed.
    final child = switch (state) {
      ViewLoading<T>() => skeleton ?? const _DefaultSkeleton(),
      ViewEmpty<T>() => EmptyView(title: emptyTitle, message: emptyMessage),
      ViewError<T>(:final message) =>
        ErrorView(message: message, onRetry: onRetry),
      final ViewData<T> data => builder(context, data),
    };

    return AnimatedSwitcher(
      duration: AppMotion.normal,
      switchInCurve: AppMotion.curve,
      // Top-aligned so a short state does not jump to the vertical centre of
      // a taller outgoing one during the cross-fade.
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      // Keyed by state TYPE: loading -> data cross-fades, but data -> newer
      // data just rebuilds in place.
      child: KeyedSubtree(key: ValueKey(state.runtimeType), child: child),
    );
  }
}

class _DefaultSkeleton extends StatelessWidget {
  const _DefaultSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBox(height: 20, width: 160),
        SizedBox(height: 12),
        SkeletonBox(height: 14),
        SizedBox(height: 8),
        SkeletonBox(height: 14, width: 220),
      ],
    );
  }
}
