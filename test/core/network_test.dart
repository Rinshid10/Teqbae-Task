import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebs_hrms/core/error/exceptions.dart';
import 'package:rebs_hrms/core/error/failures.dart';
import 'package:rebs_hrms/core/network/cached_fetch.dart';
import 'package:rebs_hrms/core/network/error_mapper.dart';
import 'package:rebs_hrms/core/utils/cached.dart';
import 'package:rebs_hrms/core/utils/result.dart';

import '../helpers/test_support.dart';

void main() {
  final options = RequestOptions(path: '/x');

  DioException badResponse(int status, Object? body) => DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(
            requestOptions: options, statusCode: status, data: body),
      );

  /// Runs a failing "request" through both mapping steps.
  Future<Failure> failureFor(DioException error) async {
    try {
      await guardRequest<void>(() async => throw error);
      fail('expected an exception');
    } catch (e) {
      return toFailure(e);
    }
  }

  group('error mapping', () {
    test('timeouts become TimeoutFailure', () async {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        final failure = await failureFor(
            DioException(requestOptions: options, type: type));
        expect(failure, isA<TimeoutFailure>(), reason: type.name);
      }
    });

    test('no connection becomes NetworkFailure', () async {
      final failure = await failureFor(DioException(
          requestOptions: options, type: DioExceptionType.connectionError));
      expect(failure, isA<NetworkFailure>());
    });

    test('5xx becomes a retryable ServerFailure', () async {
      final failure = await failureFor(badResponse(
          500, {'code': 'INTERNAL_ERROR', 'message': 'Simulated server error.'}));
      expect(failure, isA<ServerFailure>());
      expect((failure as ServerFailure).statusCode, 500);
    });

    test('409 becomes RejectedFailure with the server code and message',
        () async {
      final failure = await failureFor(badResponse(409, {
        'code': 'ATTENDANCE_ALREADY_EXISTS',
        'message': 'A check-in already exists.',
      })) as RejectedFailure;
      expect(failure.code, 'ATTENDANCE_ALREADY_EXISTS');
      expect(failure.message, 'A check-in already exists.');
      expect(failure.fieldErrors, isEmpty);
    });

    test('422 with an errors list maps every field', () async {
      final failure = await failureFor(badResponse(422, {
        'code': 'REASON_TOO_SHORT',
        'message': 'Reason must have at least 10 characters.',
        'field': 'reason',
        'errors': [
          {
            'code': 'REASON_TOO_SHORT',
            'message': 'Reason must have at least 10 characters.',
            'field': 'reason',
          },
          {
            'code': 'LEAVE_OVERLAP',
            'message': 'These dates overlap an existing request.',
            'field': 'start_date',
          },
        ],
      })) as RejectedFailure;
      expect(failure.field, 'reason');
      expect(failure.fieldErrors, {
        'reason': 'Reason must have at least 10 characters.',
        'start_date': 'These dates overlap an existing request.',
      });
    });

    test('an error body that is not JSON still produces a usable failure',
        () async {
      final failure =
          await failureFor(badResponse(404, '<html>Not found</html>'));
      expect(failure, isA<RejectedFailure>());
      expect((failure as RejectedFailure).code, 'HTTP_404');
    });

    test('an unexpected response shape is a ServerFailure, not a crash', () {
      expect(toFailure(TypeError()), isA<ServerFailure>());
    });
  });

  group('cachedFetch', () {
    final clock = FakeClock.mondayMorning();
    final earlier = DateTime.utc(2026, 11, 15);

    Future<Result<Cached<String>>> run({
      required bool refresh,
      required Future<String> Function() remote,
      Cached<String>? cache,
      void Function(String)? onSave,
    }) =>
        cachedFetch<String>(
          refresh: refresh,
          clock: clock,
          fetchRemote: remote,
          saveCache: (value, at) async => onSave?.call(value),
          readCache: () async => cache,
        );

    test('refresh: fresh data is returned and saved', () async {
      String? saved;
      final result = await run(
          refresh: true, remote: () async => 'fresh', onSave: (v) => saved = v);

      final cached = (result as Success<Cached<String>>).value;
      expect(cached.value, 'fresh');
      expect(cached.isStale, isFalse);
      expect(cached.fetchedAt, clock.now);
      expect(saved, 'fresh');
    });

    test('refresh fails: the cache is served, marked stale, with the error',
        () async {
      final result = await run(
        refresh: true,
        remote: () async => throw const NetworkException(),
        cache: Cached('saved', fetchedAt: earlier, isStale: true),
      );

      final cached = (result as Success<Cached<String>>).value;
      expect(cached.value, 'saved');
      expect(cached.isStale, isTrue);
      expect(cached.fetchedAt, earlier);
      expect(cached.refreshError, isA<NetworkFailure>());
    });

    test('refresh fails and the cache is empty: failure', () async {
      final result = await run(
          refresh: true, remote: () async => throw const NetworkException());
      expect((result as Fail<Cached<String>>).failure, isA<NetworkFailure>());
    });

    test('no refresh: the cache is returned without calling the server',
        () async {
      var remoteCalls = 0;
      final result = await run(
        refresh: false,
        remote: () async {
          remoteCalls++;
          return 'fresh';
        },
        cache: Cached('saved', fetchedAt: earlier, isStale: true),
      );

      expect((result as Success<Cached<String>>).value.value, 'saved');
      expect(remoteCalls, 0);
    });

    test('no refresh but nothing cached: falls through to the server',
        () async {
      final result = await run(refresh: false, remote: () async => 'fresh');
      expect((result as Success<Cached<String>>).value.value, 'fresh');
    });
  });
}
