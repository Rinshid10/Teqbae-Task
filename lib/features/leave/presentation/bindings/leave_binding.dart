import 'package:get/get.dart';

import '../../../../core/utils/clock.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/usecases/get_leave_overview.dart';
import '../../../sync/presentation/sync_service.dart';
import '../../domain/usecases/submit_leave_request.dart';
import '../../domain/usecases/validate_leave_request.dart';
import '../controllers/leave_controller.dart';
import '../models/leave_ui.dart';

class LeaveBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => LeaveController(
        getOverview: Get.find<GetLeaveOverview>(),
        validateRequest: Get.find<ValidateLeaveRequest>(),
        submitRequest: Get.find<SubmitLeaveRequest>(),
        sync: Get.find<SyncService>(),
        clock: Get.find<Clock>(),
        format: Get.find<AppFormat>(),
        mapper: Get.find<LeaveUiMapper>(),
      ),
    );
  }
}
