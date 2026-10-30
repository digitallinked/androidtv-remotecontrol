import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:atv_remote/src/framing.dart';
import 'package:atv_remote/src/identity.dart';
import 'package:atv_remote/src/pairing_secret.dart';
import 'package:atv_remote/src/proto/polo.pb.dart';
import 'package:atv_remote/src/proto/remotemessage.pb.dart';
import 'package:atv_remote/src/testing/fake_tv_identity.dart';
import 'package:atv_remote/testing.dart';
import 'package:test/test.dart';

// Generated lazily, once per test run (RSA keygen is slow).
final ClientIdentity _clientA = ClientIdentity.generate(commonName: 'phone-a');
final ClientIdentity _clientB = ClientIdentity.generate(commonName: 'phone-b');

final ClientIdentity _clientC = ClientIdentity.generate(commonName: 'phone-c');

const Duration _wait = Duration(seconds: 5);

/// A raw TLS connection to the fake TV that decodes frames into a queue.
class _Peer {
  _Peer._(this.socket) {
    socket.listen(
      (chunk) {
        bytesReceived += chunk.length;
        _frames.addAll(_decoder.add(chunk));
        _wake();
      },
      onError: (Object _) => _finish(),
      onDone: _finish,
    );
  }

  static Future<_Peer> connect(int port, ClientIdentity identity) async {
    final socket = await SecureSocket.connect(
      InternetAddress.loopbackIPv4,
      port,
      context: securityContextFor(identity),
      onBadCertificate: (_) => true,
    ).timeout(_wait);
    final peer = _Peer._(socket);
    addTearDown(peer.close);
    return peer;
  }

  final SecureSocket socket;
  final FrameDecoder _decoder = FrameDecoder();
  final List<Uint8List> _frames = [];
  final List<Completer<void>> _waiters = [];
  bool _done = false;
  int bytesReceived = 0;

  void _finish() {
    _done = true;
    _wake();
  }

  void _wake() {
    for (final w in _waiters) {
      if (!w.isCompleted) w.complete();
    }
    _waiters.clear();
  }

  Future<void> _block() {
    final waiter = Completer<void>();
    _waiters.add(waiter);
    return waiter.future.timeout(_wait);
  }

  /// Next frame payload, or `null` if the connection ends first.
  Future<Uint8List?> nextFrame() async {
    while (_frames.isEmpty) {
      if (_done) return null;
      await _block();
    }
    return _frames.removeAt(0);
  }

  Future<void> waitUntilClosed() async {
    while (!_done) {
      await _block();
    }
  }

  Future<OuterMessage> nextOuter() async =>
      OuterMessage.fromBuffer((await nextFrame())!);

  Future<RemoteMessage> nextRemote() async =>
      RemoteMessage.fromBuffer((await nextFrame())!);

  void sendOuter(OuterMessage m) => socket.add(encodeFrame(m.writeToBuffer()));

  void sendRemote(RemoteMessage m) =>
      socket.add(encodeFrame(m.writeToBuffer()));

  Future<void> close() async => socket.destroy();
}

OuterMessage _outer({
  PairingRequest? pairingRequest,
  Options? options,
  Configuration? configuration,
  Secret? secret,
}) => OuterMessage(
  protocolVersion: 2,
  status: OuterMessage_Status.STATUS_OK,
  pairingRequest: pairingRequest,
  options: options,
  configuration: configuration,
  secret: secret,
);

/// Runs the whole polo flow and returns the TV's reply to the secret.
Future<OuterMessage> _pair(
  FakeTvServer tv,
  ClientIdentity identity, {
  bool wrongSecret = false,
}) async {
  final peer = await _Peer.connect(tv.pairingPort, identity);
  peer.sendOuter(
    _outer(
      pairingRequest: PairingRequest(
        serviceName: 'atvremote',
        clientName: 'test phone',
      ),
    ),
  );
  expect((await peer.nextOuter()).hasPairingRequestAck(), isTrue);

  final encoding = Options_Encoding(
    type: Options_Encoding_EncodingType.ENCODING_TYPE_HEXADECIMAL,
    symbolLength: 6,
  );
  peer.sendOuter(
    _outer(
      options: Options(
        inputEncodings: [encoding],
        preferredRole: Options_RoleType.ROLE_TYPE_INPUT,
      ),
    ),
  );
  final options = await peer.nextOuter();
  expect(options.hasOptions(), isTrue);
  expect(options.options.preferredRole, Options_RoleType.ROLE_TYPE_INPUT);

  peer.sendOuter(
    _outer(
      configuration: Configuration(
        encoding: encoding,
        clientRole: Options_RoleType.ROLE_TYPE_INPUT,
      ),
    ),
  );
  expect((await peer.nextOuter()).hasConfigurationAck(), isTrue);

  final code = tv.displayedCode;
  expect(code, matches(RegExp(r'^[0-9A-F]{6}$')));
  final secret = computePairingSecret(
    client: identity.publicParts,
    server: rsaPublicPartsFromCertificateDer(peer.socket.peerCertificate!.der),
    code: code!,
  );
  peer.sendOuter(
    _outer(secret: Secret(secret: wrongSecret ? Uint8List(32) : secret)),
  );
  return peer.nextOuter();
}

Future<FakeTvServer> _start({
  bool sendPings = false,
  Duration pingInterval = const Duration(milliseconds: 200),
  bool rejectUnknownClients = true,
}) async {
  final tv = await FakeTvServer.start(
    sendPings: sendPings,
    pingInterval: pingInterval,
    rejectUnknownClients: rejectUnknownClients,
  );
  addTearDown(tv.close);
  return tv;
}

/// Connects to the remote port and completes the configure/set-active
/// handshake the way a real client does.
Future<_Peer> _connectRemote(FakeTvServer tv, ClientIdentity identity) async {
  final peer = await _Peer.connect(tv.remotePort, identity);
  expect((await peer.nextRemote()).hasRemoteConfigure(), isTrue);
  peer.sendRemote(
    RemoteMessage(
      remoteConfigure: RemoteConfigure(
        code1: 622,
        deviceInfo: RemoteDeviceInfo(model: 'phone', vendor: 'test'),
      ),
    ),
  );
  expect((await peer.nextRemote()).hasRemoteSetActive(), isTrue);
  peer.sendRemote(RemoteMessage(remoteSetActive: RemoteSetActive(active: 622)));
  return peer;
}

Future<void> _eventually(bool Function() condition) async {
  final deadline = DateTime.now().add(_wait);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Condition not met within $_wait');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  setUpAll(() {
    trustClientCertificate(_clientA);
    trustClientCertificate(_clientB);
  });

  test('pairing request is acknowledged with status OK', () async {
    final tv = await _start();
    final peer = await _Peer.connect(tv.pairingPort, _clientA);

    peer.sendOuter(
      _outer(
        pairingRequest: PairingRequest(
          serviceName: 'atvremote',
          clientName: 'test phone',
        ),
      ),
    );

    final reply = await peer.nextOuter();
    expect(reply.hasPairingRequestAck(), isTrue);
    expect(reply.status, OuterMessage_Status.STATUS_OK);
    expect(reply.protocolVersion, 2);
  });

  test('pairing with the displayed code is acknowledged', () async {
    final tv = await _start();
    expect(tv.displayedCode, isNull);

    final reply = await _pair(tv, _clientA);

    expect(reply.hasSecretAck(), isTrue);
    expect(reply.status, OuterMessage_Status.STATUS_OK);
  });

  test('pairing with a wrong secret reports a bad secret', () async {
    final tv = await _start();

    final reply = await _pair(tv, _clientA, wrongSecret: true);

    expect(reply.hasSecretAck(), isFalse);
    expect(reply.status, OuterMessage_Status.STATUS_BAD_SECRET);

    // ... and the client is not paired.
    final peer = await _Peer.connect(tv.remotePort, _clientA);
    expect(await peer.nextFrame(), isNull);
  });

  test(
    'unknown client cert is closed on the remote port without bytes',
    () async {
      final tv = await _start();
      final peer = await _Peer.connect(tv.remotePort, _clientB);

      await peer.waitUntilClosed();

      expect(peer.bytesReceived, 0);
    },
  );

  test(
    'rejectUnknownClients false lets any cert onto the remote port',
    () async {
      final tv = await _start(rejectUnknownClients: false);
      final peer = await _Peer.connect(tv.remotePort, _clientB);

      expect((await peer.nextRemote()).hasRemoteConfigure(), isTrue);
    },
  );

  test('paired client receives RemoteConfigure then RemoteSetActive', () async {
    final tv = await _start();
    await _pair(tv, _clientA);

    final peer = await _Peer.connect(tv.remotePort, _clientA);
    final configure = await peer.nextRemote();
    expect(configure.hasRemoteConfigure(), isTrue);
    expect(configure.remoteConfigure.code1, 622);
    expect(configure.remoteConfigure.deviceInfo.model, 'FakeTV');

    peer.sendRemote(
      RemoteMessage(remoteConfigure: RemoteConfigure(code1: 622)),
    );
    expect((await peer.nextRemote()).hasRemoteSetActive(), isTrue);
  });

  test('setActiveFirst sends pushes, SetActive, then Configure', () async {
    final tv = await FakeTvServer.start(
      sendPings: false,
      setActiveFirst: true,
      initialPushes: [RemoteMessage(remoteStart: RemoteStart(started: true))],
    );
    addTearDown(tv.close);
    await _pair(tv, _clientA);

    final peer = await _Peer.connect(tv.remotePort, _clientA);
    expect((await peer.nextRemote()).hasRemoteStart(), isTrue);
    expect((await peer.nextRemote()).hasRemoteSetActive(), isTrue);
    expect((await peer.nextRemote()).hasRemoteConfigure(), isTrue);

    peer
      ..sendRemote(RemoteMessage(remoteSetActive: RemoteSetActive(active: 1)))
      ..sendRemote(RemoteMessage(remoteSetActive: RemoteSetActive(active: 2)))
      ..sendRemote(RemoteMessage(remoteConfigure: RemoteConfigure(code1: 3)));
    await tv.waitForActiveClient();
    await _eventually(
      () => tv.setActiveReplyCount == 2 && tv.configureReplyCount == 1,
    );
    expect(tv.receivedActiveCode, 2);
    expect(tv.receivedConfigure!.code1, 3);
  });

  test('forgetClients makes a previously paired cert unknown', () async {
    final tv = await _start();
    await _pair(tv, _clientA);

    tv.forgetClients();

    final peer = await _Peer.connect(tv.remotePort, _clientA);
    await peer.waitUntilClosed();
    expect(peer.bytesReceived, 0);
  });

  test('records keys, app links and typed text from the client', () async {
    final tv = await _start();
    await _pair(tv, _clientA);
    final peer = await _connectRemote(tv, _clientA);

    peer
      ..sendRemote(
        RemoteMessage(
          remoteKeyInject: RemoteKeyInject(
            keyCode: RemoteKeyCode.KEYCODE_DPAD_UP,
            direction: RemoteDirection.SHORT,
          ),
        ),
      )
      ..sendRemote(
        RemoteMessage(
          remoteKeyInject: RemoteKeyInject(
            keyCode: RemoteKeyCode.KEYCODE_VOLUME_UP,
            direction: RemoteDirection.START_LONG,
          ),
        ),
      )
      ..sendRemote(
        RemoteMessage(
          remoteAppLinkLaunchRequest: RemoteAppLinkLaunchRequest(
            appLink: 'market://launch?id=com.netflix.ninja',
          ),
        ),
      )
      ..sendRemote(
        RemoteMessage(
          remoteImeBatchEdit: RemoteImeBatchEdit(
            imeCounter: 1,
            fieldCounter: 1,
            editInfo: [
              RemoteEditInfo(
                insert: 1,
                textFieldStatus: RemoteImeObject(value: 'hello'),
              ),
            ],
          ),
        ),
      );

    await _eventually(() => tv.receivedText.isNotEmpty);
    expect(tv.receivedKeyCodes, [19, 24]);
    expect(tv.receivedAppLinks, ['market://launch?id=com.netflix.ninja']);
    expect(tv.receivedText, 'hello');
  });

  test(
    'pushes volume, current app, IME show and power to the client',
    () async {
      final tv = await _start();
      await _pair(tv, _clientA);
      final peer = await _connectRemote(tv, _clientA);
      await tv.waitForActiveClient();

      tv
        ..sendVolume(level: 7, max: 100, muted: true)
        ..sendCurrentApp('com.netflix.ninja')
        ..sendImeShow()
        ..setPowerOn(false);

      final volume = await peer.nextRemote();
      expect(volume.remoteSetVolumeLevel.volumeLevel, 7);
      expect(volume.remoteSetVolumeLevel.volumeMax, 100);
      expect(volume.remoteSetVolumeLevel.volumeMuted, isTrue);
      final app = await peer.nextRemote();
      expect(app.remoteImeKeyInject.appInfo.appPackage, 'com.netflix.ninja');
      expect((await peer.nextRemote()).hasRemoteImeShowRequest(), isTrue);
      final power = await peer.nextRemote();
      expect(power.hasRemoteStart(), isTrue);
      expect(power.remoteStart.started, isFalse);
    },
  );

  test('pings the client and sees its responses', () async {
    final tv = await _start();
    await _pair(tv, _clientA);
    final peer = await _connectRemote(tv, _clientA);
    await tv.waitForActiveClient();
    expect(tv.clientAnsweredLastPing, isFalse);

    // Pings are sent by hand, so the test decides when each one is sent and
    // no timer tick can arrive late and look like a missed answer.
    tv.ping();
    final first = await peer.nextRemote();
    expect(first.hasRemotePingRequest(), isTrue);
    final n = first.remotePingRequest.val1;
    peer.sendRemote(
      RemoteMessage(remotePingResponse: RemotePingResponse(val1: n)),
    );
    await _eventually(() => tv.clientAnsweredLastPing);

    tv.ping();
    final second = await peer.nextRemote();
    expect(second.remotePingRequest.val1, n + 1);
  });

  test('closes a client that ignores three pings', () async {
    final tv = await _start(
      sendPings: true,
      pingInterval: const Duration(milliseconds: 40),
    );
    await _pair(tv, _clientA);
    final peer = await _connectRemote(tv, _clientA);

    await peer.waitUntilClosed();

    expect(tv.clientAnsweredLastPing, isFalse);
  });

  test('dropConnections closes clients but keeps listening', () async {
    final tv = await _start();
    await _pair(tv, _clientA);
    final peer = await _connectRemote(tv, _clientA);

    await tv.dropConnections();
    await peer.waitUntilClosed();

    final again = await _Peer.connect(tv.remotePort, _clientA);
    expect((await again.nextRemote()).hasRemoteConfigure(), isTrue);
  });

  test('a client trusted after the server started can still pair', () async {
    final tv = await _start();
    trustClientCertificate(_clientC);

    final reply = await _pair(tv, _clientC);

    expect(reply.hasSecretAck(), isTrue);
  });

  test('waitForActiveClient completes once SetActive was processed', () async {
    final tv = await _start();
    await _pair(tv, _clientA);
    final waiting = tv.waitForActiveClient();
    await _connectRemote(tv, _clientA);

    await waiting;

    // Already active: completes at once.
    await tv.waitForActiveClient(timeout: const Duration(milliseconds: 50));
  });

  test('waitForActiveClient times out without an active client', () async {
    final tv = await _start();

    await expectLater(
      tv.waitForActiveClient(timeout: const Duration(milliseconds: 50)),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('clientAnsweredLastPing is false after the client is dropped', () async {
    final tv = await _start();
    await _pair(tv, _clientA);
    final peer = await _connectRemote(tv, _clientA);
    await tv.waitForActiveClient();
    tv.ping();
    final ping = await peer.nextRemote();
    peer.sendRemote(
      RemoteMessage(
        remotePingResponse: RemotePingResponse(
          val1: ping.remotePingRequest.val1,
        ),
      ),
    );
    await _eventually(() => tv.clientAnsweredLastPing);

    await tv.dropConnections();

    expect(tv.clientAnsweredLastPing, isFalse);
  });

  test('clientAnsweredLastPing is false after the client hangs up', () async {
    final tv = await _start();
    await _pair(tv, _clientA);
    final peer = await _connectRemote(tv, _clientA);
    await tv.waitForActiveClient();
    tv.ping();
    final ping = await peer.nextRemote();
    peer.sendRemote(
      RemoteMessage(
        remotePingResponse: RemotePingResponse(
          val1: ping.remotePingRequest.val1,
        ),
      ),
    );
    await _eventually(() => tv.clientAnsweredLastPing);

    await peer.close();

    await _eventually(() => !tv.clientAnsweredLastPing);
  });

  test('key_codes_stream_emits_each_injected_key', () async {
    final tv = await _start();
    await _pair(tv, _clientA);
    final peer = await _connectRemote(tv, _clientA);
    final emitted = <int>[];
    final subscription = tv.keyCodes.listen(emitted.add);
    addTearDown(subscription.cancel);

    peer.sendRemote(
      RemoteMessage(
        remoteKeyInject: RemoteKeyInject(
          keyCode: RemoteKeyCode.KEYCODE_HOME,
          direction: RemoteDirection.SHORT,
        ),
      ),
    );

    await _eventually(() => emitted.isNotEmpty);
    expect(emitted, [3]);
    expect(tv.receivedKeyCodes, [3]);
  });

  test('counts_open_and_accepted_remote_connections', () async {
    final tv = await _start();
    expect(tv.openRemoteConnections, 0);
    expect(tv.acceptedRemoteConnections, 0);
    await _pair(tv, _clientA);

    final peer = await _connectRemote(tv, _clientA);
    await tv.waitForActiveClient();
    expect(tv.openRemoteConnections, 1);
    expect(tv.acceptedRemoteConnections, 1);

    await peer.close();
    await _eventually(() => tv.openRemoteConnections == 0);
    expect(tv.acceptedRemoteConnections, 1);
  });
}
