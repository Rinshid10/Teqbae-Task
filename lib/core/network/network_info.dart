/// Whether the device currently has a network connection.
///
/// An interface with no plugin imports, so the domain layer can depend on it
/// and tests can fake it. The real implementation is
/// ConnectivityNetworkInfo.
abstract class NetworkInfo {
  Future<bool> get isConnected;

  /// Emits true when a connection appears and false when it is lost.
  Stream<bool> get onStatusChange;
}
