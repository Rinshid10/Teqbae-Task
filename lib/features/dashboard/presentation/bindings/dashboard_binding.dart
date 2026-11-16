import 'package:get/get.dart';

import '../../../../core/utils/clock.dart';
import '../../../../core/utils/formatters.dart';
import '../../../attendance/domain/usecases/get_attendance_overview.dart';
import '../../../attendance/presentation/models/attendance_ui.dart';
import '../../../employee/domain/usecases/get_employee.dart';
import '../../../leave/domain/usecases/get_leave_overview.dart';
import '../../../sync/domain/repositories/outbox_repository.dart';
import '../../../sync/presentation/sync_service.dart';
import '../controllers/dashboard_controller.dart';

class DashboardBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => DashboardController(
        getEmployee: Get.find<GetEmployee>(),
        getAttendance: Get.find<GetAttendanceOverview>(),
        getLeave: Get.find<GetLeaveOverview>(),
        outbox: Get.find<OutboxRepository>(),
        sync: Get.find<SyncService>(),
        clock: Get.find<Clock>(),
        format: Get.find<AppFormat>(),
        attendanceMapper: Get.find<AttendanceUiMapper>(),
      ),
    );
  }
}
