/// Failures are *expected* error outcomes that travel through the app as
/// values (inside a `Result`), as opposed to exceptions, which are thrown by
/// the data sources and converted to failures in the repositories.
///
/// The class is sealed, so a `switch` over a Failure must handle every type —
/// the compiler tells us if we add a new one and forget a case.
/// Pure Dart: the domain layer imports this file.
sealed class Failure {
  const Failure(this.message);

  /// Human-readable text that is safe to show in the UI.
  final String message;

  @override
  String toString() => '$runtimeType($message)';
}

/// The device has no route to the server (offline, DNS, connection refused).
/// The request definitely did not reach the server.
final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection.']);
}

/// The request was sent but no response came back in time. The server MAY
/// have processed it — callers must retry with the same idempotency key.
final class TimeoutFailure extends Failure {
  const TimeoutFailure([super.message = 'The server took too long to respond.']);
}

/// 5xx or an unreadable response. Worth retrying later.
final class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.statusCode});
  final int? statusCode;
}

/// The server understood the request and said no (409 / 422).
/// Retrying the same request will not help.
final class RejectedFailure extends Failure {
  const RejectedFailure(
    super.message, {
    required this.code,
    this.field,
    this.fieldErrors = const {},
  });

  /// Machine-readable code from the error body, e.g. ATTENDANCE_ALREADY_EXISTS.
  final String code;

  /// Form field the (first) error belongs to, when the server names one.
  final String? field;

  /// Every field error the server reported: API field name -> message.
  /// Used by forms to mark all wrong fields at once.
  final Map<String, String> fieldErrors;
}

/// A local business rule said no before anything was sent to the server.
final class ValidationFailure extends Failure {
  const ValidationFailure(
    super.message, {
    required this.code,
    this.fieldErrors = const {},
  });

  final String code;

  /// Same keys as [RejectedFailure.fieldErrors], so a form handles local and
  /// server validation with one code path.
  final Map<String, String> fieldErrors;
}

/// Why a location fix could not be obtained. Each value maps to its own
/// message and recovery action in the attendance UI.
enum LocationIssue { serviceDisabled, denied, deniedForever, timeout, unavailable }

final class LocationFailure extends Failure {
  const LocationFailure(super.message, {required this.issue});
  final LocationIssue issue;
}

/// Reading or writing the local database failed.
final class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Could not read saved data.']);
}
