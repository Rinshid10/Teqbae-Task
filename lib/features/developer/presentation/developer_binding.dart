import 'package:get/get.dart';

import '../../../app/config/app_config.dart';
import '../../attendance/data/services/device_location_service.dart';
import '../../attendance/data/services/mock_location_service.dart';
import '../../employee/domain/usecases/get_employee.dart';
import '../../employee/domain/usecases/get_office.dart';
import '../domain/developer_repository.dart';
import 'developer_controller.dart';

class DeveloperBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => DeveloperController(
        repository: Get.find<DeveloperRepository>(),
        locationService: Get.find<SwitchableLocationService>(),
        getOffice: Get.find<GetOffice>(),
        getEmployee: Get.find<GetEmployee>(),
        // Always the real GPS: "use my current location" must not return
        // a simulated position.
        deviceLocation: const DeviceLocationService(),
        config: Get.find<AppConfig>(),
      ),
    );
  }
}
