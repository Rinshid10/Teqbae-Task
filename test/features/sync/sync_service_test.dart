import 'package:flutter_test/flutter_test.dart';
import 'package:rebs_hrms/core/database/app_database.dart';
import 'package:rebs_hrms/core/error/failures.dart';
import 'package:rebs_hrms/core/utils/result.dart';
import 'package:rebs_hrms/features/sync/data/datasources/outbox_local_data_source.dart';
import 'package:rebs_hrms/features/sync/data/repositories/outbox_repository_impl.dart';
import 'package:rebs_hrms/features/sync/domain/entities/outbox_event.dart';
import 'package:rebs_hrms/features/sync/domain/usecases/process_outbox.dart';
import 'package:rebs_hrms/features/sync/presentation/sync_service.dart';

import '../../helpers/test_support.dart';

/// Tests WHEN the service syncs (triggers, retry, debounce). Timings are
/// shrunk to milliseconds and awaited for real, because real file storage runs outside
/// Dart's fake-time zone.
void main() {
  late AppDatabase database;
  late OutboxRepositoryImpl outbox;
  late FakeSender sender;
  late FakeNetworkInfo network;
  late FakeClock clock;
  late SyncService service;

  const tick = Duration(milliseconds: 20);
  Future<void> wait([int ticks = 6]) => Future<void>.delayed(tick * ticks);

  setUp(() async {
    database = await openTestDatabase();
    clock = FakeClock.mondayMorning();
    outbox = OutboxRepositoryImpl(
        local: OutboxLocalDataSource(database), clock: clock);
    sender = FakeSender();
    network = FakeNetworkInfo();
    service = SyncService(
      processOutbox: ProcessOutbox(
          outbox: outbox,
          sender: sender,
          attendance: FakeAttendanceRepository()),
      outbox: outbox,
      networkInfo: network,
      reconnectDebounce: tick,
      backoff: (_) => tick,
    );
  });

  tearDown(() async {
    service.onClose();
    await wait(2); // let any in-flight run finish before closing the db
    await database.close();
  });

  Future<void> queueCheckIn([String id = 'evt-1']) => outbox.add(
        eventId: id,
        type: AttendanceEventType.checkIn,
        occurredAt: clock.now,
        workDate: '2026-11-16',
        lat: 0,
        lng: 0,
        accuracy: null,
      );

  test('app start delivers events left over from the last session', () async {
    await queueCheckIn();

    service.onInit(); // what Get.put does at startup
    await wait();

    expect(sender.sentEventIds, ['evt-1']);
    expect(service.pendingCount.value, 0);
    expect(service.isSyncing.value, isFalse);
  });

  test('pendingCount follows the outbox', () async {
    sender.respond = (_) async => const Fail(NetworkFailure());
    network.connected = false; // so no automatic retry interferes
    service.onInit();
    await wait(2);

    await queueCheckIn();
    await wait(2);

    expect(service.pendingCount.value, 1);
  });

  test('a temporary failure is retried automatically after the backoff',
      () async {
    await queueCheckIn();
    var calls = 0;
    sender.respond = (event) async =>
        ++calls == 1 ? const Fail(TimeoutFailure()) : const Success('att_1');

    final first = await service.syncNow();
    expect(first.blockedBy, isA<TimeoutFailure>());
    expect(service.lastFailure.value, isA<TimeoutFailure>());
    expect(service.pendingCount.value, 1);

    await wait(); // the retry timer fires

    // Same event id both times; now synced.
    expect(sender.sentEventIds, ['evt-1', 'evt-1']);
    expect(service.pendingCount.value, 0);
    expect(service.lastFailure.value, isNull);
  });

  test('no automatic retry while offline; reconnecting triggers the sync',
      () async {
    await queueCheckIn();
    network.connected = false;
    sender.respond = (_) async => const Fail(NetworkFailure());

    await service.syncNow();
    await wait();
    expect(sender.sent, hasLength(1)); // the retry timer did not send

    service.onInit(); // start listening to connectivity
    await wait(2);
    sender
      ..sent.clear()
      ..respond = null; // the server is reachable again
    network.emit(true);
    await wait();

    expect(sender.sentEventIds, ['evt-1']);
    expect(service.pendingCount.value, 0);
  });

  test('a flapping connection triggers one sync, not several', () async {
    service.onInit();
    await wait(2);
    await queueCheckIn();
    sender.sent.clear();

    // On, off, on within the debounce window.
    network.emit(true);
    network.emit(false);
    network.emit(true);
    await wait();

    expect(sender.sent, hasLength(1));
  });

  test('syncNow while a run is in progress is skipped', () async {
    await queueCheckIn();

    final first = service.syncNow();
    final second = await service.syncNow();
    await first;

    expect(second.skipped, isTrue);
    expect(sender.sent, hasLength(1));
  });
}
