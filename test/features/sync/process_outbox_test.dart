import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hive/hive.dart';
import 'package:rebs_hrms/core/database/app_database.dart';
import 'package:rebs_hrms/core/error/exceptions.dart';
import 'package:rebs_hrms/core/error/failures.dart';
import 'package:rebs_hrms/core/utils/result.dart';
import 'package:rebs_hrms/features/attendance/data/datasources/attendance_remote_data_source.dart';
import 'package:rebs_hrms/features/sync/data/datasources/outbox_local_data_source.dart';
import 'package:rebs_hrms/features/sync/data/models/outbox_event_model.dart';
import 'package:rebs_hrms/features/sync/data/repositories/attendance_event_sender_impl.dart';
import 'package:rebs_hrms/features/sync/data/repositories/outbox_repository_impl.dart';
import 'package:rebs_hrms/features/sync/domain/entities/outbox_event.dart';
import 'package:rebs_hrms/features/sync/domain/usecases/process_outbox.dart';

import '../../helpers/test_support.dart';

class _MockRemote extends Mock implements AttendanceRemoteDataSource {}

class _FakeEvent extends Fake implements OutboxEventModel {}

void main() {
  late AppDatabase database;
  late OutboxRepositoryImpl outbox;
  late FakeAttendanceRepository attendance;
  late FakeSender sender;
  late FakeClock clock;
  late ProcessOutbox processOutbox;

  setUpAll(() => registerFallbackValue(_FakeEvent()));

  OutboxRepositoryImpl repositoryFor(AppDatabase db) =>
      OutboxRepositoryImpl(local: OutboxLocalDataSource(db), clock: clock);

  setUp(() async {
    database = await openTestDatabase();
    clock = FakeClock.mondayMorning();
    outbox = repositoryFor(database);
    attendance = FakeAttendanceRepository();
    sender = FakeSender();
    processOutbox = ProcessOutbox(
        outbox: outbox, sender: sender, attendance: attendance);
  });

  tearDown(() => database.close());

  /// Queues an event directly (the rules are tested elsewhere).
  Future<OutboxEvent> queue(
    String id,
    AttendanceEventType type, {
    String workDate = '2026-11-16',
    OutboxRepositoryImpl? into,
  }) async {
    final result = await (into ?? outbox).add(
      eventId: id,
      type: type,
      occurredAt: clock.now,
      workDate: workDate,
      lat: 9.9312,
      lng: 76.2673,
      accuracy: 8,
    );
    clock.advance(const Duration(hours: 1));
    return (result as Success<OutboxEvent>).value;
  }

  Future<Map<String, OutboxEvent>> byId() async =>
      {for (final e in await outbox.all()) e.eventId: e};

  const timeout = Fail<String?>(TimeoutFailure());

  test('events are sent one at a time in seq order and become SYNCED',
      () async {
    await queue('in-mon', AttendanceEventType.checkIn);
    await queue('out-mon', AttendanceEventType.checkOut);
    await queue('in-tue', AttendanceEventType.checkIn, workDate: '2026-11-17');

    final result = await processOutbox();

    expect(sender.sentEventIds, ['in-mon', 'out-mon', 'in-tue']);
    expect(result.synced, 3);
    expect(result.blockedBy, isNull);
    final events = await byId();
    expect(events.values.every((e) => e.status == SyncStatus.synced), isTrue);
    expect(events['in-mon']!.serverRecordId, isNotNull);
    expect(await outbox.unsentCount(), 0);
  });

  test('a failing first event blocks the ones behind it', () async {
    await queue('in-mon', AttendanceEventType.checkIn);
    await queue('out-mon', AttendanceEventType.checkOut);
    sender.respond = (_) async => timeout;

    final result = await processOutbox();

    // Only the first was attempted; the check-out was never sent ahead of it.
    expect(sender.sentEventIds, ['in-mon']);
    expect(result.blockedBy, isA<TimeoutFailure>());
    final events = await byId();
    expect(events['in-mon']!.status, SyncStatus.pending);
    expect(events['in-mon']!.attempts, 1);
    expect(events['in-mon']!.lastError, isNotNull);
    expect(events['out-mon']!.status, SyncStatus.pending);
    expect(events['out-mon']!.attempts, 0);
  });

  test('a timeout then a retry sends the SAME event_id', () async {
    await queue('in-mon', AttendanceEventType.checkIn);
    var calls = 0;
    // First attempt: the server saved it but the response was lost.
    // Second attempt: the server recognises the id and answers normally.
    sender.respond = (event) async =>
        ++calls == 1 ? timeout : const Success('att_11');

    final first = await processOutbox();
    final second = await processOutbox();

    expect(first.blockedBy, isA<TimeoutFailure>());
    expect(second.synced, 1);
    expect(sender.sentEventIds, ['in-mon', 'in-mon']);
    final event = (await byId())['in-mon']!;
    expect(event.status, SyncStatus.synced);
    expect(event.serverRecordId, 'att_11');
    expect(event.attempts, 1);
  });

  test('network errors and 5xx also keep the event PENDING', () async {
    await queue('in-mon', AttendanceEventType.checkIn);

    sender.respond = (_) async => const Fail(NetworkFailure());
    expect((await processOutbox()).blockedBy, isA<NetworkFailure>());

    sender.respond =
        (_) async => const Fail(ServerFailure('Boom', statusCode: 500));
    expect((await processOutbox()).blockedBy, isA<ServerFailure>());

    final event = (await byId())['in-mon']!;
    expect(event.status, SyncStatus.pending);
    expect(event.attempts, 2);
  });

  test(
      'a rejected CHECK_IN is REJECTED with its reason, its CHECK_OUT is '
      'rejected too, and later days still sync', () async {
    await queue('in-mon', AttendanceEventType.checkIn);
    await queue('out-mon', AttendanceEventType.checkOut);
    await queue('in-tue', AttendanceEventType.checkIn, workDate: '2026-11-17');
    sender.respond = (event) async => event.eventId == 'in-mon'
        ? const Fail(RejectedFailure('A check-in already exists.',
            code: 'ATTENDANCE_ALREADY_EXISTS'))
        : Success('srv-${event.seq}');

    final result = await processOutbox();

    // The check-out was never sent: we already know it cannot succeed.
    expect(sender.sentEventIds, ['in-mon', 'in-tue']);
    expect(result.rejected, 1);
    expect(result.synced, 1);
    expect(result.blockedBy, isNull);
    final events = await byId();
    expect(events['in-mon']!.status, SyncStatus.rejected);
    expect(events['in-mon']!.lastError, 'A check-in already exists.');
    expect(events['out-mon']!.status, SyncStatus.rejected);
    expect(events['out-mon']!.lastError, 'Check-in was rejected');
    expect(events['in-tue']!.status, SyncStatus.synced);
  });

  test('a rejected CHECK_OUT does not touch the check-in', () async {
    await queue('in-mon', AttendanceEventType.checkIn);
    await queue('out-mon', AttendanceEventType.checkOut);
    sender.respond = (event) async => event.eventId == 'out-mon'
        ? const Fail(RejectedFailure('Too far', code: 'OUTSIDE_GEOFENCE'))
        : const Success('att_1');

    await processOutbox();

    final events = await byId();
    expect(events['in-mon']!.status, SyncStatus.synced);
    expect(events['out-mon']!.status, SyncStatus.rejected);
  });

  test('pending events survive closing and reopening the database', () async {
    // Hive boxes are found by name, so the database opened in setUp is
    // closed first; this test then uses its own folder on disk.
    await database.close();
    final dir = await Directory.systemTemp.createTemp('rebs_outbox_test');
    addTearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    var fileDb = await openTestDatabase(directory: dir.path);
    var fileOutbox = repositoryFor(fileDb);
    await queue('in-mon', AttendanceEventType.checkIn, into: fileOutbox);
    await queue('out-mon', AttendanceEventType.checkOut, into: fileOutbox);
    await fileDb.close(); // "the app was killed"

    // "the app was restarted": the same folder is opened again.
    fileDb = await openTestDatabase(directory: dir.path);
    fileOutbox = repositoryFor(fileDb);

    final restored = await fileOutbox.all();
    expect(restored.map((e) => e.eventId), ['in-mon', 'out-mon']);
    expect(restored.every((e) => e.status == SyncStatus.pending), isTrue);

    // ...and they still sync, in the original order.
    final result = await ProcessOutbox(
            outbox: fileOutbox, sender: sender, attendance: attendance)
        .call();
    expect(sender.sentEventIds, ['in-mon', 'out-mon']);
    expect(result.synced, 2);
  });

  test('an event left in SYNCING by a crash is sent again', () async {
    final event = await queue('in-mon', AttendanceEventType.checkIn);
    await outbox.markSyncing(event.seq); // crashed mid-request

    final result = await processOutbox();

    expect(sender.sentEventIds, ['in-mon']);
    expect(result.synced, 1);
  });

  test('a second run while one is in progress does nothing (mutex)', () async {
    await queue('in-mon', AttendanceEventType.checkIn);
    final gate = Completer<void>();
    sender.respond = (event) async {
      await gate.future;
      return const Success('att_1');
    };

    final first = processOutbox();
    final second = await processOutbox();
    gate.complete();
    final firstResult = await first;

    expect(second.skipped, isTrue);
    expect(firstResult.synced, 1);
    expect(sender.sent, hasLength(1)); // sent once, not twice
  });

  test('the attendance cache is refreshed after a successful sync only',
      () async {
    await processOutbox(); // empty queue
    expect(attendance.refreshCalls, 0);

    await queue('in-mon', AttendanceEventType.checkIn);
    await processOutbox();
    expect(attendance.refreshCalls, 1);
  });

  group('AttendanceEventSenderImpl (how server answers are classified)', () {
    late _MockRemote remote;
    late AttendanceEventSenderImpl realSender;

    setUp(() {
      remote = _MockRemote();
      realSender = AttendanceEventSenderImpl(remote);
      processOutbox = ProcessOutbox(
          outbox: outbox, sender: realSender, attendance: attendance);
    });

    test('201 with a record id is SYNCED with that id', () async {
      when(() => remote.postEvent(any()))
          .thenAnswer((_) async => {'id': 'att_42'});
      await queue('in-mon', AttendanceEventType.checkIn);

      await processOutbox();

      expect((await byId())['in-mon']!.serverRecordId, 'att_42');
    });

    test('409 DUPLICATE for the same event_id is treated as SYNCED',
        () async {
      when(() => remote.postEvent(any())).thenThrow(const ApiException(
          statusCode: 409,
          code: 'DUPLICATE_EVENT',
          message: 'Event already processed.'));
      await queue('in-mon', AttendanceEventType.checkIn);

      final result = await processOutbox();

      expect(result.synced, 1);
      expect(result.rejected, 0);
      expect((await byId())['in-mon']!.status, SyncStatus.synced);
    });

    test('409 ATTENDANCE_ALREADY_EXISTS (a different event) is REJECTED',
        () async {
      when(() => remote.postEvent(any())).thenThrow(const ApiException(
          statusCode: 409,
          code: 'ATTENDANCE_ALREADY_EXISTS',
          message: 'A check-in already exists for 2026-11-16.'));
      await queue('in-mon', AttendanceEventType.checkIn);

      final result = await processOutbox();

      expect(result.rejected, 1);
      final event = (await byId())['in-mon']!;
      expect(event.status, SyncStatus.rejected);
      expect(event.lastError, 'A check-in already exists for 2026-11-16.');
    });

    test('a timeout exception keeps the event PENDING for retry', () async {
      when(() => remote.postEvent(any()))
          .thenThrow(const RequestTimeoutException());
      await queue('in-mon', AttendanceEventType.checkIn);

      final result = await processOutbox();

      expect(result.blockedBy, isA<TimeoutFailure>());
      expect((await byId())['in-mon']!.status, SyncStatus.pending);
    });

    test('500 keeps the event PENDING for retry', () async {
      when(() => remote.postEvent(any())).thenThrow(const ApiException(
          statusCode: 500, code: 'INTERNAL_ERROR', message: 'Boom'));
      await queue('in-mon', AttendanceEventType.checkIn);

      final result = await processOutbox();

      expect(result.blockedBy, isA<ServerFailure>());
      expect((await byId())['in-mon']!.status, SyncStatus.pending);
    });
  });

  test('backoff grows 2s, 4s, 8s ... and is capped at 60s', () {
    expect(backoffDelay(0), Duration.zero);
    expect(backoffDelay(1), const Duration(seconds: 2));
    expect(backoffDelay(2), const Duration(seconds: 4));
    expect(backoffDelay(3), const Duration(seconds: 8));
    expect(backoffDelay(5), const Duration(seconds: 32));
    expect(backoffDelay(6), const Duration(seconds: 60));
    expect(backoffDelay(50), const Duration(seconds: 60));
  });
}
