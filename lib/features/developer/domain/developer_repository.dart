import '../../../core/utils/result.dart';

/// The scenarios the mock server can simulate. `wire` is the name the
/// server's /__mock/scenario endpoint expects.
enum MockScenario {
  success('success'),
  slow('slow'),
  timeout('timeout'),
  timeoutAfterCommit('timeout_after_commit'),
  serverError('server_error'),
  duplicateAttendance('duplicate_attendance'),
  leaveValidation('leave_validation');

  const MockScenario(this.wire);
  final String wire;

  static MockScenario fromWire(String? value) => values.firstWhere(
        (s) => s.wire == value,
        orElse: () => MockScenario.success,
      );
}

/// Reviewer tools behind the Developer Settings screen. It talks only to
/// the mock server's control endpoints and to local storage; a production
/// build would simply not register it.
abstract class DeveloperRepository {
  /// Which scenario the mock server is currently in.
  Future<Result<MockScenario>> currentScenario();

  Future<Result<void>> setScenario(MockScenario scenario);

  /// Restores the server's seed data and the `success` scenario.
  Future<Result<void>> resetServer();

  /// Deletes every local cache table and the outbox.
  Future<void> clearLocalData();
}
