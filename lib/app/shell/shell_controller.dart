import 'package:get/get.dart';

/// Holds which bottom-navigation tab is selected. Kept in a controller (not
/// widget state) so any feature can switch tabs, e.g. a dashboard shortcut
/// that jumps to Attendance.
class ShellController extends GetxController {
  final tabIndex = 0.obs;

  void selectTab(int index) => tabIndex.value = index;
}
