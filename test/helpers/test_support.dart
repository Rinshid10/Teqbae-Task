import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:rebs_hrms/core/database/app_database.dart';
import 'package:rebs_hrms/core/error/failures.dart';
import 'package:rebs_hrms/core/network/network_info.dart';
import 'package:rebs_hrms/core/utils/cached.dart';
import 'package:rebs_hrms/core/utils/clock.dart';
import 'package:rebs_hrms/core/utils/result.dart';
import 'package:rebs_hrms/features/attendance/domain/entities/attendance_record.dart';
import 'package:rebs_hrms/features/attendance/domain/entities/geo_position.dart';
import 'package:rebs_hrms/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:rebs_hrms/features/attendance/domain/services/location_service.dart';
import 'package:rebs_hrms/features/employee/domain/entities/employee.dart';
import 'package:rebs_hrms/features/employee/domain/repositories/employee_repository.dart';
import 'package:rebs_hrms/features/sync/domain/entities/outbox_event.dart';
import 'package:rebs_hrms/features/sync/domain/repositories/attendance_event_sender.dart';
import 'package:hive/hive.dart';

/// The office used across tests (same as the app's default config).
const testOffice = Office(lat: 9.9312, lng: 76.2673, radiusMeters: 200);

/// A position a few metres from the office door.
const insideOffice = GeoPosition(lat: 9.93125, lng: 76.2673, accuracy: 8);

/// About 840 m north of the office (0.00755 degrees of latitude).
const outsideOffice = GeoPosition(lat: 9.93875, lng: 76.2673, accuracy: 12);

/// A clock the test controls. The company timezone is a fixed UTC+05:30
/// (India), so no timezone database is needed.
class FakeClock extends Clock {
  FakeClock(this.now);

  /// Monday 16 Nov 2026, 09:00 in the company timezone (03:30 UTC).
  factory FakeClock.mondayMorning() =>
      FakeClock(DateTime.utc(2026, 11, 16, 3, 30));

  DateTime now;

  void advance(Duration by) => now = now.add(by);

  @override
  DateTime nowUtc() => now;

  @override
  DateTime toCompanyTime(DateTime instant) =>
      instant.toUtc().add(const Duration(hours: 5, minutes: 30));
}

/// Opens the app's real Hive storage in a temporary folder (no device
/// needed). Each call gets a fresh, empty folder unless [directory] is
/// given — pass the same folder twice to test closing and reopening.
///
/// The folder is deleted when the test ends.
Future<AppDatabase> openTestDatabase({String? directory}) async {
  final ownsFolder = directory == null;
  final folder = directory ??
      (await Directory.systemTemp.createTemp('rebs_hive_test')).path;
  final database = await AppDatabase.open(directory: folder);
  if (ownsFolder) {
    addTearDown(() async {
      // Files must be closed before Windows allows deleting the folder.
      await Hive.close();
      try {
        await Directory(folder).delete(recursive: true);
      } catch (_) {
        // A leftover temp folder is harmless.
      }
    });
  }
  return database;
}

class FakeLocationService implements LocationService {
  FakeLocationService([this.result = const Success(insideOffice)]);

  Result<GeoPosition> result;

  /// When set, currentPosition() waits for it — used to hold a call "in
  /// flight" while a second one is made.
  Completer<void>? gate;
  int calls = 0;
  int openedLocationSettings = 0;
  int openedAppSettings = 0;

  @override
  Future<Result<GeoPosition>> currentPosition() async {
    calls++;
    await gate?.future;
    return result;
  }

  @override
  Future<void> openLocationSettings() async => openedLocationSettings++;

  @override
  Future<void> openAppSettings() async => openedAppSettings++;
}

class FakeEmployeeRepository implements EmployeeRepository {
  FakeEmployeeRepository({this.employee});

  Employee? employee;

  @override
  Future<Employee?> cachedEmployee() async => employee;

  @override
  Future<Result<Cached<Employee>>> getEmployee({bool refresh = true}) async {
    final e = employee;
    if (e == null) return const Fail(NetworkFailure());
    return Success(Cached(e, fetchedAt: DateTime.utc(2026, 11, 16)));
  }
}

/// Server attendance records held in a list.
class FakeAttendanceRepository implements AttendanceRepository {
  final records = <AttendanceRecord>[];
  int refreshCalls = 0;

  @override
  Future<AttendanceRecord?> cachedRecordFor(String workDate) async =>
      records.where((r) => r.workDate == workDate).firstOrNull;

  @override
  Future<Cached<List<AttendanceRecord>>?> cachedRecords() async =>
      Cached(List.of(records),
          fetchedAt: DateTime.utc(2026, 11, 16), isStale: true);

  @override
  Future<Result<Cached<List<AttendanceRecord>>>> getRecords({
    bool refresh = true,
  }) async {
    if (refresh) refreshCalls++;
    return Success(
        Cached(List.of(records), fetchedAt: DateTime.utc(2026, 11, 16)));
  }
}

/// A scripted server: each send is answered by [respond], and every event
/// it was asked to send is recorded in [sent].
class FakeSender implements AttendanceEventSender {
  FakeSender([this.respond]);

  Future<Result<String?>> Function(OutboxEvent event)? respond;
  final sent = <OutboxEvent>[];

  List<String> get sentEventIds => [for (final e in sent) e.eventId];

  @override
  Future<Result<String?>> send(OutboxEvent event) async {
    sent.add(event);
    final handler = respond;
    return handler == null ? Success('srv-${event.seq}') : handler(event);
  }
}

class FakeNetworkInfo implements NetworkInfo {
  FakeNetworkInfo({this.connected = true});

  bool connected;
  final _controller = StreamController<bool>.broadcast();

  /// Simulates the connection appearing or disappearing.
  void emit(bool value) {
    connected = value;
    _controller.add(value);
  }

  @override
  Future<bool> get isConnected async => connected;

  @override
  Stream<bool> get onStatusChange => _controller.stream;
}
