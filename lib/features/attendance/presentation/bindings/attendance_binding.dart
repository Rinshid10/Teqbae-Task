import 'package:get/get.dart';

import '../../../../core/utils/clock.dart';
import '../../../../core/utils/formatters.dart';
import '../../../sync/domain/repositories/outbox_repository.dart';
import '../../../sync/presentation/sync_service.dart';
import '../../domain/services/location_service.dart';
import '../../domain/usecases/check_attendance_location.dart';
import '../../domain/usecases/get_attendance_overview.dart';
import '../../domain/usecases/record_attendance_event.dart';
import '../controllers/attendance_controller.dart';
import '../models/attendance_ui.dart';

/// Creates the attendance controller. Get.find is used only here; the
/// controller itself receives everything through its constructor.
class AttendanceBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => AttendanceController(
        getOverview: Get.find<GetAttendanceOverview>(),
        checkLocation: Get.find<CheckAttendanceLocation>(),
        recordEvent: Get.find<RecordAttendanceEvent>(),
        location: Get.find<LocationService>(),
        outbox: Get.find<OutboxRepository>(),
        sync: Get.find<SyncService>(),
        clock: Get.find<Clock>(),
        format: Get.find<AppFormat>(),
        mapper: Get.find<AttendanceUiMapper>(),
      ),
    );
  }
}
