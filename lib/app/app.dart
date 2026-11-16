import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/strings/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/app_messenger.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';

/// Root widget. The binding is passed in so main() can hand over the opened
/// database and tests could supply a different composition root.
class RebsApp extends StatelessWidget {
  const RebsApp({super.key, required this.initialBinding});

  final Bindings initialBinding;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // The design defines a light theme only.
      themeMode: ThemeMode.light,
      // Lets controllers show snackbars without a BuildContext.
      scaffoldMessengerKey: AppMessenger.key,
      initialBinding: initialBinding,
      initialRoute: AppRoutes.splash,
      getPages: AppPages.pages,
      defaultTransition: Transition.cupertino,
      transitionDuration: AppMotion.normal,
    );
  }
}
