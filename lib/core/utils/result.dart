import '../error/failures.dart';

/// The return type of every repository and use case: either a value or a
/// [Failure]. Using a sealed class instead of throwing means the caller is
/// forced by the compiler to handle the failure branch.
///
/// The failing variant is called [Fail] (not `Failure`) only because the
/// name `Failure` is already taken by the error type it carries.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;

  /// Collapses both branches into one value.
  R fold<R>(R Function(T value) onSuccess, R Function(Failure failure) onFail) {
    return switch (this) {
      Success<T>(:final value) => onSuccess(value),
      Fail<T>(:final failure) => onFail(failure),
    };
  }
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Fail<T> extends Result<T> {
  const Fail(this.failure);
  final Failure failure;
}
