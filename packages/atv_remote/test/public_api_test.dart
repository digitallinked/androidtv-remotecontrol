// Compile-level guarantee: everything the app needs is reachable through the
// single public entry point.

import 'package:atv_remote/atv_remote.dart';
import 'package:test/test.dart';

abstract class _Discovery implements TvDiscovery {}

void main() {
  test('exports the public surface', () {
    // Identity and pairing.
    final symbols = <Object?>[
      ClientIdentity,
      RsaPublicParts,
      rsaPublicPartsFromCertificateDer,
      computePairingSecret,
      InvalidPairingCodeException,
      PairingClient,
      PairingException,
      PairingFailure.badSecret,
      // Sockets.
      defaultSocketConnector,
      socketConnectorWithTimeout,
      // Remote control.
      RemoteClient,
      DeviceInfo,
      KeyCodes.home,
      KeyDirection.short,
      RemoteEvent,
      RemoteReady,
      PowerStateChanged,
      VolumeChanged,
      CurrentAppChanged,
      ImeShowRequested,
      RemoteErrorReceived,
      RemoteClosed,
      RemoteCloseReason.closedByClient,
      RemoteConnectException,
      // Connection.
      TvConnection,
      ConnectionState,
      ConnectionStatus.connected,
      NotConnectedException,
      Backoff,
      // Discovery and wake-on-LAN.
      DiscoveredTv,
      TvDiscovery,
      _Discovery,
      parseServiceRecord,
      buildMagicPacket,
      sendWakeOnLan,
    ];
    expect(symbols, everyElement(isNotNull));

    // A typedef is only usable as a type.
    SocketConnector? connector;
    expect(connector, isNull);
    final packet = buildMagicPacket('00:11:22:33:44:55');
    expect(packet, hasLength(102));
  });
}
