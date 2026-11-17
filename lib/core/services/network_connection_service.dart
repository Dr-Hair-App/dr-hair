import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

typedef SocketLookupFunction = Future<List<InternetAddress>> Function(String host);
typedef RawSocketConnectFunction = Future<Socket> Function(
  dynamic host,
  int port, {
  dynamic sourceAddress,
  int sourcePort,
  Duration? timeout,
});

class NetworkConnectionService {
  final Connectivity _connectivity;
  final SocketLookupFunction _lookup;
  final RawSocketConnectFunction _socketConnect;

  static NetworkConnectionService? _instance;
  static NetworkConnectionService get instance =>
      _instance ??= NetworkConnectionService();

  NetworkConnectionService({
    Connectivity? connectivity,
    SocketLookupFunction? lookup,
    RawSocketConnectFunction? socketConnect,
  })  : _connectivity = connectivity ?? Connectivity(),
        _lookup = lookup ?? InternetAddress.lookup,
        _socketConnect = socketConnect ?? Socket.connect;

  /// Returns true if an active network interface is connected AND can route packets.
  Future<bool> hasInternet({Duration timeout = const Duration(seconds: 4)}) async {
    try {
      // In Flutter headless test runner without native connectivity plugin:
      if (Platform.environment.containsKey('FLUTTER_TEST') &&
          _connectivity.runtimeType.toString() == 'Connectivity') {
        return true;
      }

      var results = await _connectivity.checkConnectivity();
      // Any result other than 'none' indicates an active interface (mobile, wifi, other, ethernet, vpn).
      // Note: Devices running ColorOS/OnePlus/Realme/Xiaomi often report ConnectivityResult.other for mobile/wifi.
      bool hasAdapter = results.any((r) => r != ConnectivityResult.none);

      if (!hasAdapter) {
        // Cold start debounce: on some Android devices, ConnectivityManager callback registers ~200-400ms after launch
        await Future.delayed(const Duration(milliseconds: 350));
        results = await _connectivity.checkConnectivity();
        hasAdapter = results.any((r) => r != ConnectivityResult.none);
        if (!hasAdapter) {
          return false;
        }
      }

      // Check candidate hosts via DNS
      final candidateHosts = <String>[
        'api.drhairindia.com',
        'google.com',
        'one.one.one.one',
      ];

      for (final host in candidateHosts) {
        try {
          final addresses = await _lookup(host).timeout(timeout);
          if (addresses.isNotEmpty && addresses[0].rawAddress.isNotEmpty) {
            return true;
          }
        } catch (_) {
          // Continue to next host
        }
      }

      // Fallback: raw TCP socket connection to public DNS IP (8.8.8.8 or 1.1.1.1 on port 53).
      // Bypasses DNS resolution completely and tests direct IP packet routing.
      for (final ip in ['8.8.8.8', '1.1.1.1']) {
        try {
          final socket = await _socketConnect(
            ip,
            53,
            timeout: const Duration(seconds: 2),
          );
          socket.destroy();
          return true;
        } catch (_) {
          // Continue
        }
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  /// Listens to network adapter connectivity changes.
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;
}
