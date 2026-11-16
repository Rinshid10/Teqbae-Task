import 'package:get/get.dart';

import '../../features/attendance/presentation/bindings/attendance_binding.dart';
import '../../features/attendance/presentation/views/attendance_success_view.dart';
import '../../features/dashboard/presentation/bindings/dashboard_binding.dart';
import '../../features/developer/presentation/developer_binding.dart';
import '../../features/developer/presentation/developer_settings_view.dart';
import '../../features/leave/presentation/bindings/leave_binding.dart';
import '../../features/leave/presentation/views/leave_form_view.dart';
import '../../features/leave/presentation/views/leave_review_view.dart';
import '../../features/sync/presentation/bindings/sync_center_binding.dart';
import '../../features/sync/presentation/views/sync_center_view.dart';
import '../shell/home_shell.dart';
import '../shell/shell_controller.dart';
import '../splash/splash_view.dart';
import 'app_routes.dart';

/// Route table. Each page declares the bindings that create its
/// controllers, so a controller lives exactly as long as its page.
abstract final class AppPages {
  static final pages = <GetPage<dynamic>>[
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashView(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.shell,
      page: () => const HomeShell(),
      transition: Transition.fadeIn,
      // The shell shows all three tabs, so it owns all three controllers.
      bindings: [
        BindingsBuilder(() => Get.lazyPut(() => ShellController())),
        DashboardBinding(),
        AttendanceBinding(),
        LeaveBinding(),
      ],
    ),
    // The next three have no binding: they reuse controllers created by
    // the shell, which is still alive underneath them.
    GetPage(
      name: AppRoutes.attendanceSuccess,
      page: () => const AttendanceSuccessView(),
    ),
    GetPage(
      name: AppRoutes.leaveForm,
      page: () => const LeaveFormView(),
    ),
    GetPage(
      name: AppRoutes.leaveReview,
      page: () => const LeaveReviewView(),
    ),
    GetPage(
      name: AppRoutes.syncCenter,
      page: () => const SyncCenterView(),
      binding: SyncCenterBinding(),
    ),
    GetPage(
      name: AppRoutes.developer,
      page: () => const DeveloperSettingsView(),
      binding: DeveloperBinding(),
    ),
  ];
}
