import 'package:flutter/widgets.dart';
import 'package:timezone/data/latest_10y.dart' as tz_data;

import 'app/app.dart';
import 'app/bindings/initial_binding.dart';
import 'core/database/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Loads the timezone database that SystemClock uses for the company
  // timezone. The "10y" build only carries rules for roughly +/-5 years
  // around its release, which keeps the app smaller and is all we need.
  tz_data.initializeTimeZones();

  // Opened before the first frame: pending outbox events must be readable
  // the moment the app starts, and the open takes only a few milliseconds.
  final database = await AppDatabase.open();

  runApp(RebsApp(initialBinding: InitialBinding(database)));
}
