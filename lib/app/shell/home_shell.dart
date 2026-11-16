import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/strings/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../features/attendance/presentation/views/attendance_view.dart';
import '../../features/dashboard/presentation/controllers/dashboard_controller.dart';
import '../../features/dashboard/presentation/views/dashboard_view.dart';
import '../../features/leave/presentation/views/leave_view.dart';
import '../../features/sync/presentation/sync_service.dart';
import '../routes/app_routes.dart';
import 'shell_controller.dart';

/// App frame: the header, the three tabs and the bottom navigation bar.
class HomeShell extends GetView<ShellController> {
  const HomeShell({super.key});

  static const _tabs = <Widget>[
    DashboardView(),
    AttendanceView(),
    LeaveView(),
  ];

  static const _titles = [
    AppStrings.tabHome,
    AppStrings.tabAttendance,
    AppStrings.tabLeave,
  ];

  @override
  Widget build(BuildContext context) {
    final dashboard = Get.find<DashboardController>();
    final sync = Get.find<SyncService>();

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Obx(
          () => TabHeader(
            title: _titles[controller.tabIndex.value],
            initials: dashboard.initials.value,
            online: sync.isOnline.value,
            // Hidden entry to the reviewer tools, debug builds only.
            onTitleLongPress: kDebugMode
                ? () => Get.toNamed<void>(AppRoutes.developer)
                : null,
          ),
        ),
      ),
      // IndexedStack keeps all three tabs alive, so switching tabs does not
      // lose scroll position.
      body: Obx(
        () => IndexedStack(index: controller.tabIndex.value, children: _tabs),
      ),
      bottomNavigationBar: Obx(
        () => AppBottomNav(
          index: controller.tabIndex.value,
          onSelected: controller.selectTab,
        ),
      ),
    );
  }
}

/// The three-item bottom bar from the design: an icon with a small label,
/// blue when selected.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.index,
    required this.onSelected,
  });

  final int index;
  final ValueChanged<int> onSelected;

  static const _items = [
    (icon: AppIcons.navHome, label: AppStrings.tabHome),
    (icon: AppIcons.navAttendance, label: AppStrings.tabAttendance),
    (icon: AppIcons.navLeave, label: AppStrings.tabLeave),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadows.nav,
      ),
      // Keeps the bar above the system gesture area.
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  for (var i = 0; i < _items.length; i++)
                    Expanded(
                      child: _NavItem(
                        icon: _items[i].icon,
                        label: _items[i].label,
                        selected: i == index,
                        onTap: () => onSelected(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: PressableScale(
        onTap: onTap,
        pressedScale: 0.94,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 20,
              child: Center(child: AppIcon(icon, color: color)),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
