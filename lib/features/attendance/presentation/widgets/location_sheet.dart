import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/status_chip.dart';
import '../models/location_flow.dart';

/// What the location sheet shows for each [LocationFlowState]. A plain
/// widget (state in, callbacks out), so every state can be widget-tested.
class LocationSheetContent extends StatelessWidget {
  const LocationSheetContent({
    super.key,
    required this.state,
    required this.isSubmitting,
    required this.onConfirm,
    required this.onCancel,
    required this.onProblemAction,
    required this.onRetry,
  });

  final LocationFlowState state;
  final bool isSubmitting;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final VoidCallback onProblemAction;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.md),
      // Cross-fades between verifying -> verified / problem.
      child: AnimatedSwitcher(
        duration: AppMotion.normal,
        switchInCurve: AppMotion.curve,
        child: switch (state) {
          LocationChecking() => _verify(null),
          LocationReady(:final ready) => _verify(ready),
          LocationProblem(:final problem) => _ProblemContent(
              key: ValueKey(problem.kind),
              problem: problem,
              onAction: onProblemAction,
              onRetry: onRetry,
              onCancel: onCancel,
            ),
        },
      ),
    );
  }

  /// The radar layout, shared by "verifying" (ready == null) and "verified".
  Widget _verify(LocationReadyUi? ready) {
    final checking = ready == null;
    return Column(
      key: const ValueKey('verify'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.geofenceCheck.toUpperCase(),
                    style: AppText.small.copyWith(
                      color: AppColors.textTertiary,
                      letterSpacing: 0.6,
                    ),
                  ),
                  Text(
                    checking
                        ? AppStrings.verifyingLocation
                        : AppStrings.locationVerified,
                    style: AppText.title,
                  ),
                ],
              ),
            ),
            IconBadge(
              icon: AppIcons.navigationArrow,
              size: 32,
              background: AppColors.successFill.withValues(alpha: 0.5),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _RadarPanel(ready: ready),
        const SizedBox(height: AppSpacing.md),
        _statusRow(ready),
        if (ready != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: _TelemetryPill(ready: ready),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: ready?.confirmLabel ?? AppStrings.verifyingShort,
          icon: AppIcons.personCheck,
          // Disabled until the position is verified; a spinner while the
          // event is being saved.
          isLoading: checking || isSubmitting,
          onPressed: onConfirm,
        ),
        const SizedBox(height: 4),
        TextLinkButton(
          label: AppStrings.cancel,
          color: AppColors.textSecondary,
          style: AppText.input,
          expand: true,
          onPressed: isSubmitting ? null : onCancel,
        ),
      ],
    );
  }

  Widget _statusRow(LocationReadyUi? ready) {
    final checking = ready == null;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: checking
            ? AppColors.panel
            : AppColors.successFill.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconBadge(
            icon: checking ? AppIcons.gpsTarget : AppIcons.check,
            size: 36,
            background: checking ? AppColors.chip : AppColors.success,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ready?.title ?? AppStrings.gettingPosition,
                  style: AppText.value,
                ),
                Text(
                  ready?.subtitle ?? AppStrings.gettingPositionHint,
                  style: AppText.small.copyWith(
                    color: checking
                        ? AppColors.textSecondary
                        : AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "09:12 AM • ±8 m accuracy • GPS locked".
class _TelemetryPill extends StatelessWidget {
  const _TelemetryPill({required this.ready});

  final LocationReadyUi ready;

  @override
  Widget build(BuildContext context) {
    Widget item(String icon, String text, {Color? color}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(icon, color: color),
            const SizedBox(width: 4),
            Text(
              text,
              style: AppText.tabular(AppText.small)
                  .copyWith(color: color ?? AppColors.textSecondary),
            ),
          ],
        );
    const dot = Text('•', style: TextStyle(color: AppColors.muted));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.fill,
        borderRadius: BorderRadius.circular(16),
      ),
      // Wrap: on a narrow phone the items flow onto a second line.
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          item(AppIcons.clock, ready.timeLabel),
          if (ready.accuracyLabel != null) ...[
            dot,
            item(AppIcons.gpsTarget, ready.accuracyLabel!),
          ],
          dot,
          item(AppIcons.lock, AppStrings.gpsLocked, color: AppColors.success),
        ],
      ),
    );
  }
}

/// The radar picture: dashed rings, the office in the centre and, once the
/// position is known, the "You" marker at its relative distance.
class _RadarPanel extends StatelessWidget {
  const _RadarPanel({required this.ready});

  final LocationReadyUi? ready;

  static const _size = 256.0;

  /// Radius, in the picture, of the ring that stands for the geofence.
  static const _fenceRadius = 96.0;

  @override
  Widget build(BuildContext context) {
    // The marker sits up and to the right of the office, at a distance
    // proportional to the real one (0 = at the office, 1 = on the fence).
    final offset = (ready?.distanceFraction ?? 0) * _fenceRadius;
    final dx = offset * math.cos(-math.pi / 4);
    final dy = offset * math.sin(-math.pi / 4);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.flat,
      ),
      child: Column(
        children: [
          // FittedBox scales the whole picture down on narrow screens.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: _size,
              height: _size,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  const AppIcon(AppIcons.radarRings),
                  if (ready == null) const _RadarSweep(),
                  if (ready != null)
                    Positioned(
                      right: 20,
                      top: 16,
                      child: _MapLabel(text: ready!.perimeterLabel),
                    ),
                  // Office marker.
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.brand,
                      shape: BoxShape.circle,
                      boxShadow: AppShadows.flat,
                    ),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const Positioned(
                    top: _size / 2 + 16,
                    child: _MapLabel(text: AppStrings.office, strong: true),
                  ),
                  if (ready != null)
                    Positioned(
                      left: _size / 2 + dx - 18,
                      top: _size / 2 + dy - 18,
                      child: const _UserMarker(),
                    ),
                  if (ready != null)
                    Positioned(
                      left: _size / 2 + dx - 40,
                      top: _size / 2 + dy - 46,
                      width: 80,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: AppShadows.flat,
                          ),
                          child: Text(
                            ready!.markerLabel,
                            maxLines: 1,
                            style: AppText.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: ready == null ? AppColors.muted : AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  AppStrings.deviceLocation,
                  style:
                      AppText.caption.copyWith(color: AppColors.textTertiary),
                ),
              ),
              Text(
                ready == null ? AppStrings.locating : AppStrings.zoneOk,
                style: AppText.monoCaption,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small grey label drawn on the radar.
class _MapLabel extends StatelessWidget {
  const _MapLabel({required this.text, this.strong = false});

  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.divider.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(strong ? 999 : 4),
      ),
      child: Text(
        text,
        style: AppText.caption.copyWith(
          color: strong ? AppColors.textPrimary : AppColors.textTertiary,
          fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );
  }
}

/// The blue "you are here" dot with two soft halos.
class _UserMarker extends StatelessWidget {
  const _UserMarker();

  @override
  Widget build(BuildContext context) {
    Widget ring(double size, double alpha) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: alpha),
            shape: BoxShape.circle,
          ),
        );
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ring(36, 0.25),
          ring(24, 0.35),
          Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ],
      ),
    );
  }
}

/// The rotating sweep shown while the position is being found.
///
/// This is the one place the app uses an AnimationController: a continuous
/// rotation cannot be expressed with the implicit-animation widgets used
/// everywhere else. It is created and disposed with the widget.
class _RadarSweep extends StatefulWidget {
  const _RadarSweep();

  @override
  State<_RadarSweep> createState() => _RadarSweepState();
}

class _RadarSweepState extends State<_RadarSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Container(
        width: 192,
        height: 192,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          // A wedge that fades out over the first sixth of the circle.
          gradient: SweepGradient(
            colors: [Color(0x261E63C7), Color(0x001E63C7)],
            stops: [0, 1 / 6],
          ),
        ),
      ),
    );
  }
}

/// Out of range, permission problems, GPS off, or an attendance rule.
class _ProblemContent extends StatelessWidget {
  const _ProblemContent({
    super.key,
    required this.problem,
    required this.onAction,
    required this.onRetry,
    required this.onCancel,
  });

  final LocationProblemUi problem;
  final VoidCallback onAction;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final isClose = problem.action == ProblemAction.close;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.sm),
        Center(child: _ProblemGraphic(problem: problem)),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: StatusChip(
            label: problem.pill,
            tone: problem.kind == ProblemKind.outside ||
                    problem.kind == ProblemKind.rule
                ? ChipTone.warning
                : ChipTone.danger,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(problem.title, textAlign: TextAlign.center, style: AppText.title),
        const SizedBox(height: 4),
        Text(problem.body, textAlign: TextAlign.center, style: AppText.body),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: problem.actionLabel,
          icon: problem.action == ProblemAction.retry ? AppIcons.refresh : null,
          onPressed: onAction,
        ),
        if (problem.showRetryLink) ...[
          const SizedBox(height: 4),
          TextLinkButton(
            label: AppStrings.retry,
            icon: AppIcons.refresh,
            expand: true,
            onPressed: onRetry,
          ),
        ],
        if (!isClose) ...[
          const SizedBox(height: 4),
          TextLinkButton(
            label: AppStrings.cancel,
            color: AppColors.textSecondary,
            style: AppText.input,
            expand: true,
            onPressed: onCancel,
          ),
        ],
      ],
    );
  }
}

/// The round picture at the top of a problem state. Out of range shows the
/// office and the user's pin with the real distance; the others show an
/// icon for the problem.
class _ProblemGraphic extends StatelessWidget {
  const _ProblemGraphic({required this.problem});

  final LocationProblemUi problem;

  @override
  Widget build(BuildContext context) {
    if (problem.kind != ProblemKind.outside) {
      final (icon, color, fill) = switch (problem.kind) {
        ProblemKind.locationOff => (
            AppIcons.locationOff,
            AppColors.warning,
            AppColors.warningFill
          ),
        ProblemKind.denied => (
            AppIcons.shieldAlert,
            AppColors.danger,
            AppColors.dangerFill
          ),
        ProblemKind.blocked => (
            AppIcons.blockCircle,
            AppColors.danger,
            AppColors.dangerFill
          ),
        ProblemKind.unavailable => (
            AppIcons.gpsOff,
            AppColors.danger,
            AppColors.dangerFill
          ),
        _ => (AppIcons.infoCircle, AppColors.warning, AppColors.warningFill),
      };
      return Container(
        width: 120,
        height: 120,
        alignment: Alignment.center,
        decoration:
            const BoxDecoration(color: AppColors.panel, shape: BoxShape.circle),
        child: IconBadge(
          icon: icon,
          size: 64,
          background: fill,
          iconColor: color,
          iconSize: 26,
        ),
      );
    }

    return SizedBox(
      width: 192,
      height: 192,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: const BoxDecoration(
              color: AppColors.panel,
              shape: BoxShape.circle,
            ),
          ),
          // Office, in the middle.
          Align(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const IconBadge(
                  icon: AppIcons.building,
                  size: 32,
                  background: AppColors.brand,
                ),
                const SizedBox(height: 4),
                Text(
                  problem.zoneLabel ?? '',
                  style: AppText.caption.copyWith(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // The user's pin, out at the edge.
          Positioned(
            right: 12,
            top: 20,
            child: Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: AppShadows.flat,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.warningDeep,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    problem.distanceLabel ?? '',
                    style: AppText.caption.copyWith(
                      fontSize: 10,
                      color: AppColors.warningOnDeep,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
