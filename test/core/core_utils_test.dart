import 'package:flutter_test/flutter_test.dart';
import 'package:rebs_hrms/core/error/failures.dart';
import 'package:rebs_hrms/core/utils/clock.dart';
import 'package:rebs_hrms/core/utils/geo_utils.dart';
import 'package:rebs_hrms/core/utils/result.dart';
import 'package:timezone/data/latest_10y.dart' as tz_data;

void main() {
  group('distanceInMeters', () {
    test('is zero for the same point', () {
      expect(distanceInMeters(9.9312, 76.2673, 9.9312, 76.2673), 0);
    });

    test('one degree of latitude is about 111.2 km', () {
      final d = distanceInMeters(0, 0, 1, 0);
      expect(d, closeTo(111195, 10));
    });

    test('a point ~150 m north of the office is inside a 200 m radius', () {
      // 0.00135 degrees of latitude is about 150 m.
      final d = distanceInMeters(9.9312, 76.2673, 9.93255, 76.2673);
      expect(d, closeTo(150, 2));
    });
  });

  group('SystemClock', () {
    setUpAll(tz_data.initializeTimeZones);

    test('work date follows the company timezone, not UTC', () {
      final clock = SystemClock('Asia/Kolkata');
      // 19:00 UTC on 1 Jan is 00:30 on 2 Jan in India (UTC+5:30).
      final instant = DateTime.utc(2026, 1, 1, 19, 0);
      expect(clock.workDateOf(instant), '2026-01-02');
      expect(clock.toCompanyTime(instant).hour, 0);
      expect(clock.toCompanyTime(instant).minute, 30);
    });

    test('just before company midnight is still the previous day', () {
      final clock = SystemClock('Asia/Kolkata');
      final instant = DateTime.utc(2026, 1, 1, 18, 29); // 23:59 IST
      expect(clock.workDateOf(instant), '2026-01-01');
    });
  });

  group('Result', () {
    test('fold picks the matching branch', () {
      const Result<int> ok = Success(2);
      const Result<int> bad = Fail(NetworkFailure());
      expect(ok.fold((v) => 'value $v', (f) => f.message), 'value 2');
      expect(bad.fold((v) => 'value $v', (f) => f.message),
          'No internet connection.');
      expect(ok.isSuccess, isTrue);
      expect(bad.isSuccess, isFalse);
    });
  });
}
