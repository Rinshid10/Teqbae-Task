import 'package:get/get.dart';

import '../../../../core/utils/formatters.dart';
import '../../../attendance/presentation/models/attendance_ui.dart';
import '../../domain/usecases/get_outbox_events.dart';
import '../controllers/sync_center_controller.dart';
import '../sync_service.dart';

class SyncCenterBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => SyncCenterController(
        getEvents: Get.find<GetOutboxEvents>(),
        sync: Get.find<SyncService>(),
        format: Get.find<AppFormat>(),
        mapper: Get.find<AttendanceUiMapper>(),
      ),
    );
  }
}
