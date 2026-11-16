import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/widgets/app_sheet.dart';
import 'controllers/attendance_controller.dart';
import 'models/location_flow.dart';
import 'widgets/location_sheet.dart';

/// The check-in / check-out journey, started from the button on Home:
///
///   1. open the sheet and verify the location
///   2. the user confirms (or the sheet explains what is wrong)
///   3. on success, show the confirmation page
///
/// It lives here, not in a controller, because it is navigation: opening a
/// sheet and pushing a page need a BuildContext.
Future<void> startAttendanceFlow(BuildContext context) async {
  final controller = Get.find<AttendanceController>();

  // Not awaited: the sheet opens immediately and shows the progress.
  unawaited(controller.startFlow());

  final recorded = await showAppSheet<bool>(
    context,
    builder: (sheetContext) => Obx(() {
      final state = controller.flow.value;
      if (state == null) return const SizedBox(height: 120);
      return LocationSheetContent(
        state: state,
        isSubmitting: controller.isSubmitting.value,
        onConfirm: () async {
          final navigator = Navigator.of(sheetContext);
          if (await controller.confirm()) navigator.pop(true);
        },
        onCancel: () => Navigator.of(sheetContext).pop(false),
        onProblemAction: () {
          if (state case LocationProblem(:final problem)
              when problem.action == ProblemAction.close) {
            Navigator.of(sheetContext).pop(false);
          } else {
            controller.onProblemAction();
          }
        },
        onRetry: controller.retryFlow,
      );
    }),
  );

  if (recorded == true) {
    await Get.toNamed<void>(AppRoutes.attendanceSuccess);
  } else {
    // Dismissed by a tap outside, the back button or Cancel.
    controller.cancelFlow();
  }
}
