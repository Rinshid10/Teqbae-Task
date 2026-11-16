/// The four things any screen can be showing. Controllers expose exactly one
/// `ViewState<T>` per screen section and the `StateBuilder` widget renders it,
/// so no view ever needs its own if/else chain of loading/error flags.
sealed class ViewState<T> {
  const ViewState();
}

final class ViewLoading<T> extends ViewState<T> {
  const ViewLoading();
}

final class ViewEmpty<T> extends ViewState<T> {
  const ViewEmpty();
}

final class ViewError<T> extends ViewState<T> {
  const ViewError(this.message);
  final String message;
}

final class ViewData<T> extends ViewState<T> {
  const ViewData(this.value, {this.isStale = false, this.isOffline = false});

  final T value;

  /// The value came from the local cache and a refresh has not succeeded yet.
  final bool isStale;

  /// The device is currently offline (drives the offline banner).
  final bool isOffline;
}
