import 'dart:io';

import 'package:rebs_mock_server/mock_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Run with:  dart run bin/server.dart            (port 8080)
///            dart run bin/server.dart --port 9090
Future<void> main(List<String> args) async {
  final portIndex = args.indexOf('--port');
  final port = portIndex >= 0 && portIndex + 1 < args.length
      ? int.parse(args[portIndex + 1])
      : int.parse(Platform.environment['PORT'] ?? '8080');

  final server = MockServer();
  final handler = const Pipeline()
      .addMiddleware(logRequestsWithBodies())
      .addHandler(server.handler);

  // anyIPv4 (0.0.0.0), not localhost: the Android emulator (10.0.2.2) and
  // real phones on the same Wi-Fi must be able to reach it.
  await shelf_io.serve(handler, InternetAddress.anyIPv4, port);

  stdout.writeln('REBS mock API listening on http://localhost:$port');
  stdout.writeln('  Android emulator: http://10.0.2.2:$port');
  stdout.writeln('  Scenarios: ${Scenario.allNames}');
  stdout.writeln('  Switch:    POST /__mock/scenario {"name":"..."}'
      '   Reset: POST /__mock/reset');
}
