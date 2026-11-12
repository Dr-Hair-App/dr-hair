import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dr_hair/core/services/network_connection_service.dart';

class _FakeConnectivity implements Connectivity {
  final List<ConnectivityResult> results;
  _FakeConnectivity(this.results);

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => results;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      Stream.value(results);
}

class _FakeSocket implements Socket {
  bool destroyed = false;

  @override
  void destroy() {
    destroyed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('NetworkConnectionService', () {
    test('returns false when connectivity adapter is none', () async {
      final service = NetworkConnectionService(
        connectivity: _FakeConnectivity([ConnectivityResult.none]),
        lookup: (_) async => [InternetAddress('8.8.8.8')],
      );

      final hasInternet = await service.hasInternet();
      expect(hasInternet, isFalse);
    });

    test('returns false when both DNS lookup and raw IP socket fail even if wifi is connected', () async {
      final service = NetworkConnectionService(
        connectivity: _FakeConnectivity([ConnectivityResult.wifi]),
        lookup: (_) async => throw const SocketException('Failed host lookup'),
        socketConnect: (host, port, {sourceAddress, int sourcePort = 0, timeout}) async =>
            throw const SocketException('Network unreachable'),
      );

      final hasInternet = await service.hasInternet();
      expect(hasInternet, isFalse);
    });

    test('returns true when mobile is connected and DNS lookup succeeds', () async {
      final service = NetworkConnectionService(
        connectivity: _FakeConnectivity([ConnectivityResult.mobile]),
        lookup: (_) async => [InternetAddress('142.250.190.46')],
      );

      final hasInternet = await service.hasInternet();
      expect(hasInternet, isTrue);
    });

    test('returns true when adapter is ConnectivityResult.other (ColorOS / custom transport)', () async {
      final service = NetworkConnectionService(
        connectivity: _FakeConnectivity([ConnectivityResult.other]),
        lookup: (_) async => [InternetAddress('142.250.190.46')],
      );

      final hasInternet = await service.hasInternet();
      expect(hasInternet, isTrue);
    });

    test('returns true via raw IP socket when DNS fails but IP routing works', () async {
      final fakeSocket = _FakeSocket();
      final service = NetworkConnectionService(
        connectivity: _FakeConnectivity([ConnectivityResult.wifi]),
        lookup: (_) async => throw const SocketException('DNS failure'),
        socketConnect: (host, port, {sourceAddress, int sourcePort = 0, timeout}) async =>
            fakeSocket,
      );

      final hasInternet = await service.hasInternet();
      expect(hasInternet, isTrue);
      expect(fakeSocket.destroyed, isTrue);
    });
  });
}
