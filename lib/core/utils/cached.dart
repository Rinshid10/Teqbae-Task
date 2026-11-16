import '../error/failures.dart';

/// A value plus where it came from. Repositories return this for everything
/// that can be shown offline, so the UI can say "showing saved data".
class Cached<T> {
  const Cached(
    this.value, {
    required this.fetchedAt,
    this.isStale = false,
    this.refreshError,
  });

  final T value;

  /// When the value was last fetched from the server. Null = never.
  final DateTime? fetchedAt;

  /// True when the value was read from the local cache rather than fetched
  /// just now.
  final bool isStale;

  /// Set when a refresh was attempted and failed, which is why the cached
  /// value is being shown. Null for a plain cache read.
  final Failure? refreshError;
}
