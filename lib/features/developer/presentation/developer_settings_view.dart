import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/content_width.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/primary_button.dart';
import '../../attendance/data/services/mock_location_service.dart';
import 'developer_controller.dart';

/// Reviewer tools: simulate a location,
/// see the office parameters, and reset all data. It is the fourth tab
/// ("Settings") of the bottom navigation, in every build type.
class DeveloperSettingsView extends GetView<DeveloperController> {
  const DeveloperSettingsView({super.key});

  // (icon, icon colour, title, subtitle) for each simulated location.
  static const _locations = {
    LocationMode.device: (
      AppIcons.gpsCrosshair,
      AppColors.textTertiary,
      AppStrings.devRealGps,
      null,
    ),
    LocationMode.inside: (
      AppIcons.officeBuilding,
      AppColors.success,
      AppStrings.devInside,
      AppStrings.devInsideHint,
    ),
    LocationMode.outside: (
      AppIcons.locationOutside,
      AppColors.warning,
      AppStrings.devOutside,
      AppStrings.devOutsideHint,
    ),
    LocationMode.denied: (
      AppIcons.shieldAlert,
      AppColors.textTertiary,
      AppStrings.devDenied,
      null,
    ),
    LocationMode.deniedForever: (
      AppIcons.blockCircle,
      AppColors.danger,
      AppStrings.devDeniedForever,
      null,
    ),
    LocationMode.unavailable: (
      AppIcons.gpsOff,
      AppColors.danger,
      AppStrings.devUnavailable,
      null,
    ),
  };

  /// The modes offered on screen. The other three (permission denied,
  /// permanently denied, GPS unavailable) can still be set at launch with
  /// --dart-define=MOCK_LOCATION, which is why they stay in [_locations].
  static const _shownModes = [
    LocationMode.device,
    LocationMode.inside,
    LocationMode.outside,
  ];

  Future<void> _reset() async {
    if (await controller.resetEverything()) {
      // Rebuild every screen from scratch so nothing shows stale data.
      await Get.offAllNamed<void>(AppRoutes.splash);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ContentWidth(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md,
                AppSpacing.page, AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const AppIcon(AppIcons.terminal),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(AppStrings.devSandbox,
                          style: AppText.title),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppIcon(AppIcons.code),
                          SizedBox(width: 6),
                          Text(AppStrings.devDebugOnly,
                              style: AppText.caption),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.panel,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppShadows.flat,
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppIcon(AppIcons.shieldCheck),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppStrings.devNoticeTitle,
                                style: AppText.labelMedium),
                            SizedBox(height: 2),
                            Text(AppStrings.devNoticeBody,
                                style: AppText.body),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ---- simulate location ----------------------------------
                Obx(
                  () => _SectionLabel(
                    icon: AppIcons.navigationArrow,
                    title: AppStrings.devSimulateLocation,
                    trailing: AppStrings.devActive(
                        _locations[controller.locationMode.value]!.$3),
                  ),
                ),
                AppCard(
                  radius: 12,
                  padding: EdgeInsets.zero,
                  shadow: AppShadows.flat,
                  child: Column(
                    children: [
                      for (final mode in _shownModes) ...[
                        if (mode != _shownModes.first) const Divider(),
                        Obx(
                          () => _RadioRow(
                            leading: AppIcon(
                              _locations[mode]!.$1,
                              color: _locations[mode]!.$2,
                            ),
                            title: _locations[mode]!.$3,
                            subtitle: _locations[mode]!.$4,
                            selected: controller.locationMode.value == mode,
                            onTap: () => controller.selectLocationMode(mode),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ---- office parameters ----------------------------------
                const _SectionLabel(
                  icon: AppIcons.building,
                  iconColor: AppColors.brand,
                  title: AppStrings.devOfficeParameters,
                  trailing: AppStrings.devLocked,
                  trailingColor: AppColors.success,
                ),
                Obx(() {
                  final office = controller.office.value;
                  return AppCard(
                    radius: 12,
                    shadow: AppShadows.flat,
                    child: Column(
                      children: [
                        _ParameterRow(
                          label: AppStrings.devCoordinates,
                          value: office?.coordinates ?? AppStrings.noValue,
                          mono: true,
                        ),
                        const Divider(height: 17),
                        _ParameterRow(
                          label: AppStrings.devRadius,
                          value: office?.radius ?? AppStrings.noValue,
                          chip: true,
                        ),
                        const Divider(height: 17),
                        _ParameterRow(
                          label: AppStrings.devTimezone,
                          value: office?.timezone ?? AppStrings.noValue,
                        ),
                        const Divider(height: 17),
                        _ParameterRow(
                          label: AppStrings.devServer,
                          value: office?.server ?? AppStrings.noValue,
                          mono: true,
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppStrings.devOfficeHint,
                  style:
                      AppText.caption.copyWith(color: AppColors.textTertiary),
                ),
                const SizedBox(height: AppSpacing.sm),
                Obx(
                  () => SecondaryButton(
                    label: AppStrings.devUseCurrentLocation,
                    icon: AppIcons.gpsCrosshair,
                    onPressed: controller.isBusy.value
                        ? null
                        : controller.useCurrentLocationAsOffice,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Obx(
                  () => SecondaryButton(
                    label: AppStrings.devEnterCoordinates,
                    icon: AppIcons.building,
                    onPressed: controller.isBusy.value
                        ? null
                        : () => showAppSheet<void>(
                              context,
                              builder: (_) =>
                                  _OfficeCoordinatesSheet(controller),
                            ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                Obx(
                  () => SecondaryButton(
                    label: AppStrings.devReset,
                    icon: AppIcons.reset,
                    color: AppColors.danger,
                    onPressed: controller.isBusy.value ? null : _reset,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppStrings.devResetHint,
                  textAlign: TextAlign.center,
                  style:
                      AppText.caption.copyWith(color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for typing the office latitude and longitude.
class _OfficeCoordinatesSheet extends StatefulWidget {
  const _OfficeCoordinatesSheet(this.controller);

  final DeveloperController controller;

  @override
  State<_OfficeCoordinatesSheet> createState() =>
      _OfficeCoordinatesSheetState();
}

class _OfficeCoordinatesSheetState extends State<_OfficeCoordinatesSheet> {
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  Map<String, String> _errors = const {};

  @override
  void dispose() {
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final errors =
        widget.controller.validateCoordinates(_lat.text, _lng.text);
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;

    final saved =
        await widget.controller.setOfficeCoordinates(_lat.text, _lng.text);
    if (saved && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(AppStrings.devOfficeSheetTitle, style: AppText.title),
          const SizedBox(height: AppSpacing.md),
          _CoordinateField(
            controller: _lat,
            label: AppStrings.devLatitude,
            hint: AppStrings.devLatitudeHint,
            error: _errors['lat'],
          ),
          const SizedBox(height: AppSpacing.sm),
          _CoordinateField(
            controller: _lng,
            label: AppStrings.devLongitude,
            hint: AppStrings.devLongitudeHint,
            error: _errors['lng'],
          ),
          const SizedBox(height: AppSpacing.lg),
          Obx(
            () => PrimaryButton(
              label: AppStrings.devSaveOffice,
              isLoading: widget.controller.isBusy.value,
              onPressed: widget.controller.isBusy.value ? null : _save,
            ),
          ),
        ],
      ),
    );
  }
}

/// One labelled number field with its error underneath.
class _CoordinateField extends StatelessWidget {
  const _CoordinateField({
    required this.controller,
    required this.label,
    required this.hint,
    this.error,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.labelMedium),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(12),
            border: error == null
                ? null
                : Border.all(color: AppColors.danger, width: 1),
          ),
          child: TextField(
            controller: controller,
            // Signed, because southern and western coordinates are negative.
            keyboardType: const TextInputType.numberWithOptions(
                signed: true, decimal: true),
            style: AppText.input,
            cursorColor: AppColors.brand,
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: hint,
              hintStyle:
                  AppText.input.copyWith(color: AppColors.textTertiary),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(error!,
              style: AppText.caption.copyWith(color: AppColors.danger)),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.title,
    required this.trailing,
    this.iconColor,
    this.trailingColor = AppColors.textTertiary,
  });

  final String icon;
  final Color? iconColor;
  final String title;
  final String trailing;
  final Color trailingColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
      child: Row(
        children: [
          AppIcon(icon, color: iconColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.labelMedium.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 0.65,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            trailing,
            style: AppText.caption.copyWith(color: trailingColor),
          ),
        ],
      ),
    );
  }
}

/// A selectable row with the design's solid radio dot on the right
/// (blue when selected, grey otherwise).
class _RadioRow extends StatelessWidget {
  const _RadioRow({
    required this.leading,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: PressableScale(
        onTap: onTap,
        pressedScale: 0.99,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 8),
          child: Row(
            children: [
              SizedBox(width: 20, child: Center(child: leading)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.input,
                    ),
                    if (subtitle != null)
                      Text(subtitle!, style: AppText.caption),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: AppMotion.normal,
                curve: AppMotion.curve,
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: selected ? AppColors.accent : AppColors.divider,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParameterRow extends StatelessWidget {
  const _ParameterRow({
    required this.label,
    required this.value,
    this.mono = false,
    this.chip = false,
  });

  final String label;
  final String value;
  final bool mono;
  final bool chip;

  @override
  Widget build(BuildContext context) {
    final style = mono
        ? AppText.monoCaption.copyWith(
            fontSize: 13,
            height: 18 / 13,
            letterSpacing: 0,
            color: AppColors.textPrimary,
          )
        : AppText.labelMedium;

    return Row(
      children: [
        Text(label, style: AppText.body),
        const SizedBox(width: 12),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: chip
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.fill,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      value,
                      style: AppText.small
                          .copyWith(color: AppColors.textPrimary),
                    ),
                  )
                : Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: style,
                  ),
          ),
        ),
      ],
    );
  }
}
