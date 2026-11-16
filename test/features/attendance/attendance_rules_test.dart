import 'package:flutter_test/flutter_test.dart';
import 'package:rebs_hrms/features/attendance/domain/entities/attendance_day.dart';
import 'package:rebs_hrms/features/attendance/domain/entities/attendance_record.dart';
import 'package:rebs_hrms/features/attendance/domain/entities/geo_position.dart';
import 'package:rebs_hrms/features/attendance/domain/rules/attendance_rules.dart';
import 'package:rebs_hrms/features/sync/domain/entities/outbox_event.dart';

import '../../helpers/test_support.dart';

void main() {
  const rules = AttendanceRules();
  const date = '2026-11-16';
  final nine = DateTime.utc(2026, 11, 16, 3, 30);
  final six = DateTime.utc(2026, 11, 16, 12, 30);

  OutboxEvent event(
    AttendanceEventType type,
    SyncStatus status, {
    DateTime? at,
    int seq = 1,
  }) =>
      OutboxEvent(
        seq: seq,
        eventId: 'evt-$seq',
        type: type,
        occurredAt: at ?? nine,
        workDate: date,
        lat: 0,
        lng: 0,
        accuracy: null,
        status: status,
        attempts: 0,
        lastError: status == SyncStatus.rejected ? 'Nope' : null,
        serverRecordId: null,
        createdAt: nine,
      );

  group('buildDay', () {
    test('no record and no events is "not checked in"', () {
      final day = rules.buildDay(date, null, const []);
      expect(day.status, TodayStatus.notCheckedIn);
      expect(day.hasAnything, isFalse);
    });

    test('a PENDING check-in already counts as checked in (unsynced)', () {
      final day = rules.buildDay(date, null,
          [event(AttendanceEventType.checkIn, SyncStatus.pending)]);
      expect(day.status, TodayStatus.checkedIn);
      expect(day.checkIn!.isSynced, isFalse);
    });

    test('a SYNCED event shows as synced even before the cache refresh', () {
      final day = rules.buildDay(date, null,
          [event(AttendanceEventType.checkIn, SyncStatus.synced)]);
      expect(day.checkIn!.isSynced, isTrue);
    });

    test('the server record wins and is always synced', () {
      final record = AttendanceRecord(
          id: 'att_1', workDate: date, checkInAt: nine, checkOutAt: six);
      final day = rules.buildDay(date, record, const []);
      expect(day.status, TodayStatus.checkedOut);
      expect(day.checkIn, AttendanceMark(time: nine, isSynced: true));
      expect(day.workedDuration, const Duration(hours: 9));
    });

    test('server check-in plus a pending local check-out', () {
      final record = AttendanceRecord(
          id: 'att_1', workDate: date, checkInAt: nine, checkOutAt: null);
      final day = rules.buildDay(date, record, [
        event(AttendanceEventType.checkOut, SyncStatus.pending, at: six),
      ]);
      expect(day.status, TodayStatus.checkedOut);
      expect(day.checkIn!.isSynced, isTrue);
      expect(day.checkOut!.isSynced, isFalse);
    });

    test('a REJECTED event does not count, but is kept with its reason', () {
      final day = rules.buildDay(date, null,
          [event(AttendanceEventType.checkIn, SyncStatus.rejected)]);
      expect(day.status, TodayStatus.notCheckedIn);
      expect(day.rejected.single.lastError, 'Nope');
      expect(day.hasAnything, isTrue);
    });
  });

  group('validate', () {
    final empty = rules.buildDay(date, null, const []);
    final checkedIn = rules.buildDay(date, null,
        [event(AttendanceEventType.checkIn, SyncStatus.pending)]);
    final checkedOut = rules.buildDay(date, null, [
      event(AttendanceEventType.checkIn, SyncStatus.synced),
      event(AttendanceEventType.checkOut, SyncStatus.pending, at: six, seq: 2),
    ]);

    test('check-in is allowed on an empty day', () {
      expect(rules.validate(AttendanceEventType.checkIn, empty, nine), isNull);
    });

    test('check-out without a check-in is rejected', () {
      final failure =
          rules.validate(AttendanceEventType.checkOut, empty, six);
      expect(failure?.code, 'CHECK_IN_REQUIRED');
    });

    test('a second check-in is rejected', () {
      final failure =
          rules.validate(AttendanceEventType.checkIn, checkedIn, six);
      expect(failure?.code, 'ALREADY_CHECKED_IN');
    });

    test('check-out after check-in is allowed, but only once', () {
      expect(
          rules.validate(AttendanceEventType.checkOut, checkedIn, six), isNull);
      expect(
          rules.validate(AttendanceEventType.checkOut, checkedOut, six)?.code,
          'ALREADY_CHECKED_OUT');
    });

    test('no new check-in after the day is complete', () {
      expect(rules.validate(AttendanceEventType.checkIn, checkedOut, six)?.code,
          'DAY_COMPLETE');
    });

    test('check-out cannot be at or before the check-in time', () {
      final failure =
          rules.validate(AttendanceEventType.checkOut, checkedIn, nine);
      expect(failure?.code, 'INVALID_ORDER');
    });
  });

  group('checkGeofence', () {
    test('inside the radius is allowed', () {
      expect(
          rules.checkGeofence(
              insideOffice, testOffice, AttendanceEventType.checkIn),
          isNull);
    });

    test('outside gives the friendly distance message', () {
      final failure = rules.checkGeofence(
          outsideOffice, testOffice, AttendanceEventType.checkIn);
      expect(failure?.code, 'OUTSIDE_GEOFENCE');
      expect(
          failure?.message,
          "You're 840 m from the office. "
          'Check-in is allowed within 200 m.');
    });

    test('just inside and just outside the 200 m boundary', () {
      // 0.0017 degrees of latitude is about 189 m; 0.0019 is about 211 m.
      const near = GeoPosition(lat: 9.9329, lng: 76.2673);
      const far = GeoPosition(lat: 9.9331, lng: 76.2673);
      expect(
          rules.checkGeofence(near, testOffice, AttendanceEventType.checkIn),
          isNull);
      expect(
          rules.checkGeofence(far, testOffice, AttendanceEventType.checkOut),
          isNotNull);
    });
  });
}
