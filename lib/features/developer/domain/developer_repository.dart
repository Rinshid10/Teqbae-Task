import '../../../core/utils/result.dart';

/// Reviewer tools behind the Developer Settings screen. It talks only to
/// the mock server's control endpoints and to local storage; a production
/// build would simply not register it.
abstract class DeveloperRepository {
  /// Moves the office geofence on the mock server. The app then picks the
  /// new office up from /employee/me, so both sides check the same place.
  Future<Result<void>> setOffice({required double lat, required double lng});

  /// Clears the server's data and restores the `success` scenario.
  Future<Result<void>> resetServer();

  /// Deletes every local cache table and the outbox.
  Future<void> clearLocalData();
}
