import 'package:connectivity_plus/connectivity_plus.dart';

import 'network_info.dart';

/// NetworkInfo backed by connectivity_plus.
///
/// Limitation worth knowing: this reports whether Wi-Fi/mobile data is
/// attached, NOT whether the server is reachable. That is fine here because
/// nothing relies on it for correctness — a request that fails anyway is
/// handled as a normal network failure. It is only used to decide when to
/// try, and to show the right message.
class ConnectivityNetworkInfo implements NetworkInfo {
  ConnectivityNetworkInfo([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  @override
  Future<bool> get isConnected async {
    try {
      return _hasConnection(await _connectivity.checkConnectivity());
    } catch (_) {
      // If the plugin cannot answer, assume online and let the request decide.
      return true;
    }
  }

  @override
  Stream<bool> get onStatusChange =>
      _connectivity.onConnectivityChanged.map(_hasConnection).distinct();
}
