import 'package:get/get.dart';

import '../../../app/config/app_config.dart';
import '../../attendance/data/services/mock_location_service.dart';
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
        config: Get.find<AppConfig>(),
      ),
    );
  }
}
