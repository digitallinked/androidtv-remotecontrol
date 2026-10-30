import 'dart:io';

import 'package:atv_remote/atv_remote.dart';
import 'package:atv_remote/testing.dart';
import 'package:test/test.dart';

import 'support/wait_for.dart';

const int _cycles = 50;

const DeviceInfo _deviceInfo = DeviceInfo(
  model: 'Test Phone',
  vendor: 'Test Vendor',
  packageName: 'com.example.remote',
  appVersion: '1.2.3',
);

/// A [RemoteClient] that reports when it is closed.
class _CountedClient extends RemoteClient {
  _CountedClient(
    this._onClose, {
    required super.host,
    required super.port,
    required super.identity,
    required super.deviceInfo,
  });

  final void Function(RemoteClient client) _onClose;

  @override
  Future<void> close() {
    _onClose(this);
    return super.close();
  }
}

/// The fixture identity from `test/fixtures/`; parsing it is much faster than
/// generating a key.
ClientIdentity _fixtureIdentity() => ClientIdentity.fromPem(
  certificatePem: File('test/fixtures/client.pem').readAsStringSync(),
  privateKeyPem: File('test/fixtures/client_key.pem').readAsStringSync(),
);

void main() {
  test(
    'no_socket_leak_after_50_disconnect_connect_cycles',
    () async {
      final identity = _fixtureIdentity();
      FakeTvServer.trustClient(identity);
      final tv = await FakeTvServer.start();
      addTearDown(tv.close);

      final pairing = PairingClient(
        host: InternetAddress.loopbackIPv4.address,
        port: tv.pairingPort,
        identity: identity,
      );
      addTearDown(pairing.close);
      await pairing.start(clientName: 'cycles test');
      await pairing.submitCode(tv.displayedCode!);

      final created = <RemoteClient>[];
      final closed = <RemoteClient>{};
      final connection = TvConnection(
        host: InternetAddress.loopbackIPv4.address,
        clientFactory: (host) {
          final client = _CountedClient(
            closed.add,
            host: host,
            port: tv.remotePort,
            identity: identity,
            deviceInfo: _deviceInfo,
          );
          created.add(client);
          return client;
        },
      );
      addTearDown(connection.dispose);

      await connection.connect();
      expect(connection.current.status, ConnectionStatus.connected);

      for (var cycle = 1; cycle <= _cycles; cycle++) {
        await connection.disconnect();
        expect(
          connection.current.status,
          ConnectionStatus.disconnected,
          reason: 'cycle $cycle',
        );
        await connection.connect();
        expect(
          connection.current.status,
          ConnectionStatus.connected,
          reason: 'cycle $cycle',
        );
      }

      await waitFor(
        () => tv.openRemoteConnections == 1,
        reason: 'the TV to see every earlier connection closed',
      );
      expect(tv.acceptedRemoteConnections, _cycles + 1);
      expect(created, hasLength(_cycles + 1));
      expect(closed, hasLength(_cycles));
      expect(closed, isNot(contains(created.last)));

      await connection.dispose();
      await waitFor(
        () => tv.openRemoteConnections == 0,
        reason: 'the TV to see the last connection closed',
      );
      expect(closed, hasLength(_cycles + 1));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
