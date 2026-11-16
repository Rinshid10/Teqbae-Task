import 'package:flutter/material.dart';

/// Shows snackbars without needing a BuildContext, so controllers can report
/// an outcome ("Check-in saved"). The key is given to GetMaterialApp.
///
/// In unit tests the key is not attached to any app, so `show` simply does
/// nothing — controllers stay testable.
abstract final class AppMessenger {
  static final key = GlobalKey<ScaffoldMessengerState>();

  static void show(String message) {
    final messenger = key.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar() // never stack snackbars
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text(message, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      );
  }
}
