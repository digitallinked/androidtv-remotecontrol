import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:atv_remote/src/framing.dart';
import 'package:atv_remote/src/identity.dart';
import 'package:atv_remote/src/pairing_client.dart';
import 'package:atv_remote/src/pairing_secret.dart';
import 'package:atv_remote/src/proto/polo.pb.dart';
import 'package:atv_remote/src/proto/remotemessage.pb.dart';
import 'package:atv_remote/src/remote_client.dart';
import 'package:pointycastle/export.dart' show SHA256Digest;
import 'package:test/test.dart';

import 'fake_tv/fake_tv_identity.dart';
import 'fake_tv/fake_tv_server.dart';
import 'support/unloadable_identity.dart';

const Duration _wait = Duration(seconds: 5);

/// The budget for setup that is not under test (the TLS connect and the
/// handshake with the in-process fake TV). A loaded machine can stall these
/// for seconds; tests of timing use their own explicit durations.
const Duration _setup = Duration(seconds: 20);

late ClientIdentity _identity;

Matcher _pairingFailure(PairingFailure reason) =>
    isA<PairingException>().having(
      (e) => e.reason,
      'reason',
      reason,
    );

PairingClient _client(
  int port, {
  Duration timeout = const Duration(seconds: 5),
}) {
  final client = PairingClient(
    host: InternetAddress.loopbackIPv4.address,
    port: port,
    identity: _identity,
    timeout: timeout,
  );
  addTearDown(client.close);
  return client;
}

Future<FakeTvServer> _startTv() async {
  final tv = await FakeTvServer.start();
  addTearDown(tv.close);
  return tv;
}

/// A code with a valid checksum for [_identity] and the fake TV that is not
/// [displayed], so the TV rejects its secret.
String _wrongButValidCode(String displayed) {
  for (var suffix = 0; suffix < 0x10000; suffix++) {
    final tail = suffix.toRadixString(16).padLeft(4, '0');
    if (tail.toUpperCase() == displayed.substring(2).toUpperCase()) continue;
    for (var prefix = 0; prefix < 256; prefix++) {
      final code = prefix.toRadixString(16).padLeft(2, '0') + tail;
      try {
        computePairingSecret(
          client: _identity.publicParts,
          server: fakeTvIdentity.publicParts,
          code: code,
        );
        return code;
      } on InvalidPairingCodeException {
        // Checksum mismatch; try the next prefix.
      }
    }
  }
  throw StateError('No wrong-but-valid code found.');
}

/// A code whose checksum byte is wrong for [displayed].
String _badChecksumCode(String displayed) {
  final prefix = int.parse(displayed.substring(0, 2), radix: 16);
  final wrong = ((prefix + 1) & 0xff).toRadixString(16).padLeft(2, '0');
  return wrong + displayed.substring(2);
}

/// A TLS server that decodes pairing messages and lets a test script the
/// replies (or stay silent).
class _ScriptedTv {
  _ScriptedTv._(this._server, this._onMessage);

  static Future<_ScriptedTv> start(
    void Function(OuterMessage message, SecureSocket socket) onMessage,
  ) async {
    final context = securityContextFor(fakeTvIdentity)
      ..setTrustedCertificatesBytes(utf8.encode(_identity.certificatePem));
    final server = await SecureServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
      context,
      requestClientCertificate: true,
    );
    final tv = _ScriptedTv._(server, onMessage);
    server.listen(tv._accept, onError: (Object _) {});
    addTearDown(tv.close);
    return tv;
  }

  final SecureServerSocket _server;
  final void Function(OuterMessage message, SecureSocket socket) _onMessage;
  final List<SecureSocket> _sockets = [];
  final Completer<OuterMessage> _first = Completer<OuterMessage>();
  final Completer<void> _firstClosed = Completer<void>();

  /// Completes when the first accepted connection ends, however it ends.
  Future<void> get firstConnectionClosed => _firstClosed.future.timeout(_wait);

  int get port => _server.port;

  /// The first message a client sent.
  Future<OuterMessage> get firstMessage => _first.future.timeout(_setup);

  void _accept(SecureSocket socket) {
    _sockets.add(socket);
    final decoder = FrameDecoder();
    socket.listen(
      (chunk) {
        for (final frame in decoder.add(chunk)) {
          final message = OuterMessage.fromBuffer(frame);
          if (!_first.isCompleted) _first.complete(message);
          _onMessage(message, socket);
        }
      },
      onError: (Object _) {
        if (!_firstClosed.isCompleted) _firstClosed.complete();
      },
      onDone: () {
        if (!_firstClosed.isCompleted) _firstClosed.complete();
      },
    );
  }

  Future<void> close() async {
    for (final socket in _sockets) {
      socket.destroy();
    }
    await _server.close();
  }
}

void _reply(SecureSocket socket, OuterMessage message) {
  message.protocolVersion = 2;
  socket.add(encodeFrame(message.writeToBuffer()));
}

void main() {
  setUpAll(() {
    _identity = ClientIdentity.generate(commonName: 'pairing-test-phone');
    FakeTvServer.trustClient(_identity);
  });

  group('PairingClient', () {
    test('unloadable_identity_fails_without_tls_library_text', () async {
      final tv = await _startTv();
      final client = PairingClient(
        host: InternetAddress.loopbackIPv4.address,
        port: tv.pairingPort,
        identity: UnloadableIdentity(_identity),
      );
      addTearDown(client.close);

      await expectLater(
        client.start(clientName: 'x'),
        throwsA(
          isA<PairingException>()
              .having(
                (e) => e.reason,
                'reason',
                PairingFailure.connectionFailed,
              )
              .having(
                (e) => e.message,
                'message',
                allOf(
                  contains('could not load the client identity'),
                  isNot(contains('BoringSSL')),
                  isNot(contains('PEM')),
                ),
              ),
        ),
      );
    });

    test('pairs_successfully', () async {
      final tv = await _startTv();
      final client = _client(tv.pairingPort, timeout: _setup);

      await client.start(clientName: 'Test phone').timeout(_setup);
      final code = tv.displayedCode;
      expect(code, isNotNull);

      await client.submitCode(code!).timeout(_setup);

      // The TV now accepts this identity on the control port.
      final socket = await SecureSocket.connect(
        InternetAddress.loopbackIPv4,
        tv.remotePort,
        context: securityContextFor(_identity),
        onBadCertificate: (_) => true,
      ).timeout(_setup);
      addTearDown(socket.destroy);
      final decoder = FrameDecoder();
      final first = await socket.expand(decoder.add).first.timeout(_setup);
      expect(RemoteMessage.fromBuffer(first).hasRemoteConfigure(), isTrue);
    });

    test('exposes_the_tv_key_hash_the_remote_client_later_sees', () async {
      final tv = await _startTv();
      final client = _client(tv.pairingPort);
      expect(client.serverPublicKeySha256, isNull);

      await client.start(clientName: 'Test phone').timeout(_wait);
      final pinned = client.serverPublicKeySha256;
      expect(pinned, hasLength(32));
      await client.submitCode(tv.displayedCode!).timeout(_wait);
      expect(client.serverPublicKeySha256, orderedEquals(pinned!));

      final remote = RemoteClient(
        host: InternetAddress.loopbackIPv4.address,
        port: tv.remotePort,
        identity: _identity,
        deviceInfo: const DeviceInfo(
          model: 'Test Phone',
          vendor: 'Test Vendor',
          packageName: 'com.example.remote',
          appVersion: '1.2.3',
        ),
      );
      addTearDown(remote.close);
      await remote.connect().timeout(_wait);

      expect(remote.serverPublicKeySha256, orderedEquals(pinned));
      final parts = fakeTvIdentity.publicParts;
      expect(
        pinned,
        orderedEquals(
          SHA256Digest().process(
            Uint8List.fromList([...parts.modulus, ...parts.exponent]),
          ),
        ),
      );
    });

    test('accepts_lower_case_code', () async {
      final tv = await _startTv();
      final client = _client(tv.pairingPort);
      await client.start(clientName: 'Test phone').timeout(_wait);
      await client.submitCode(tv.displayedCode!.toLowerCase()).timeout(_wait);
    });

    test('surfaces_bad_secret_status', () async {
      final tv = await _startTv();
      final client = _client(tv.pairingPort);
      await client.start(clientName: 'Test phone').timeout(_wait);

      await expectLater(
        client.submitCode(_wrongButValidCode(tv.displayedCode!)),
        throwsA(_pairingFailure(PairingFailure.badSecret)),
      );
    });

    test('session_is_over_after_bad_secret', () async {
      final tv = await _startTv();
      final client = _client(tv.pairingPort);
      await client.start(clientName: 'Test phone').timeout(_wait);
      final code = tv.displayedCode!;
      await expectLater(
        client.submitCode(_wrongButValidCode(code)),
        throwsA(_pairingFailure(PairingFailure.badSecret)),
      );

      // The real TV invalidates the code, so retrying must start over.
      await expectLater(client.submitCode(code), throwsStateError);
    });

    test('invalid_code_never_sent', () async {
      final tv = await _startTv();
      final client = _client(tv.pairingPort);
      await client.start(clientName: 'Test phone').timeout(_wait);
      final code = tv.displayedCode!;

      await expectLater(
        client.submitCode(_badChecksumCode(code)),
        throwsA(_pairingFailure(PairingFailure.invalidCode)),
      );
      await expectLater(
        client.submitCode('12'),
        throwsA(_pairingFailure(PairingFailure.invalidCode)),
      );

      // Nothing reached the TV, and the socket is still open: the corrected
      // code works. Had a Secret been sent, the TV's BAD_SECRET reply would
      // already be queued and make this retry fail.
      await client.submitCode(code).timeout(_wait);
    });

    test('times_out_when_server_silent', () async {
      final tv = await _ScriptedTv.start((message, socket) {});
      final client = _client(
        tv.port,
        timeout: const Duration(milliseconds: 200),
      );

      await expectLater(
        client.start(clientName: 'Test phone'),
        throwsA(_pairingFailure(PairingFailure.timeout)),
      );
    });

    test('connection_refused', () async {
      final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = probe.port;
      await probe.close();
      final client = _client(port);

      await expectLater(
        client.start(clientName: 'Test phone'),
        throwsA(_pairingFailure(PairingFailure.connectionFailed)),
      );
    });

    test('tls_handshake_failure_is_connection_failed', () async {
      // A plain TCP server cannot complete a TLS handshake.
      final plain = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(plain.close);
      final sockets = <Socket>[];
      addTearDown(() {
        for (final s in sockets) {
          s.destroy();
        }
      });
      plain.listen((s) {
        sockets.add(s);
        s
          ..add(utf8.encode('not tls\n'))
          ..listen((_) {}, onError: (Object _) {});
      });
      final client = _client(plain.port);

      await expectLater(
        client.start(clientName: 'Test phone'),
        throwsA(_pairingFailure(PairingFailure.connectionFailed)),
      );
    });

    test('stalled_handshake_times_out_promptly', () async {
      // Accepts TCP, then never speaks TLS.
      final plain = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(plain.close);
      final accepted = <Socket>[];
      addTearDown(() {
        for (final s in accepted) {
          s.destroy();
        }
      });
      plain.listen((s) {
        accepted.add(s);
        s.listen((_) {}, onError: (Object _) {});
      });
      final client = _client(
        plain.port,
        timeout: const Duration(milliseconds: 200),
      );
      final clock = Stopwatch()..start();

      await expectLater(
        client.start(clientName: 'Test phone'),
        throwsA(_pairingFailure(PairingFailure.timeout)),
      );
      // Bounded by `timeout`, not by the 10 s default of the connector.
      expect(clock.elapsed, lessThan(const Duration(seconds: 3)));
    });

    test('handshake_completing_after_timeout_is_destroyed', () async {
      // Accepts TCP at once but only starts the TLS handshake after the
      // client has given up.
      final plain = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(plain.close);
      final accepted = Completer<Socket>();
      plain.listen((s) {
        if (!accepted.isCompleted) accepted.complete(s);
      });
      final client = _client(
        plain.port,
        timeout: const Duration(milliseconds: 200),
      );
      await expectLater(
        client.start(clientName: 'Test phone'),
        throwsA(_pairingFailure(PairingFailure.timeout)),
      );

      final tcp = await accepted.future.timeout(_wait);
      final secure = await SecureSocket.secureServer(
        tcp,
        securityContextFor(fakeTvIdentity),
      ).timeout(_wait);
      addTearDown(secure.destroy);
      final closed = Completer<void>();
      secure.listen(
        (_) {},
        onError: (Object _) {
          if (!closed.isCompleted) closed.complete();
        },
        onDone: () {
          if (!closed.isCompleted) closed.complete();
        },
      );

      // The late TLS session was closed by the client, not leaked.
      await closed.future.timeout(_wait);
    });

    test('socket_arriving_after_timeout_is_destroyed', () async {
      final tv = await _ScriptedTv.start((message, socket) {});
      final gate = Completer<void>();
      final client = PairingClient(
        host: InternetAddress.loopbackIPv4.address,
        port: tv.port,
        identity: _identity,
        timeout: const Duration(milliseconds: 100),
        // A slow connector that only finishes once the test lets it.
        connector: (host, port, context) async {
          await gate.future;
          return SecureSocket.connect(
            host,
            port,
            context: context,
            onBadCertificate: (_) => true,
          );
        },
      );
      addTearDown(client.close);

      await expectLater(
        client.start(clientName: 'Test phone'),
        throwsA(_pairingFailure(PairingFailure.timeout)),
      );
      gate.complete();

      // The late socket reaches the TV and is then closed by the client.
      await tv.firstConnectionClosed;
    });

    test('socket_arriving_after_close_is_destroyed', () async {
      final tv = await _ScriptedTv.start((message, socket) {});
      final gate = Completer<void>();
      final client = PairingClient(
        host: InternetAddress.loopbackIPv4.address,
        port: tv.port,
        identity: _identity,
        connector: (host, port, context) async {
          await gate.future;
          return SecureSocket.connect(
            host,
            port,
            context: context,
            onBadCertificate: (_) => true,
          );
        },
      );
      addTearDown(client.close);
      final outcome = expectLater(
        client.start(clientName: 'Test phone'),
        throwsA(_pairingFailure(PairingFailure.connectionFailed)),
      );
      await client.close();
      gate.complete();

      await outcome;
      await tv.firstConnectionClosed;
    });

    test('sends_pairing_request_first', () async {
      final tv = await _ScriptedTv.start((message, socket) {});
      // A roomy budget: the TLS handshake with the fake must not time out
      // before the request is sent. The test ends the pairing by closing it.
      final client = _client(tv.port, timeout: _setup);
      final started = client.start(clientName: 'Living room phone');
      // The TV never answers; only the request matters here.
      unawaited(started.then<void>((_) {}, onError: (Object _) {}));

      final first = await tv.firstMessage;
      expect(first.protocolVersion, 2);
      expect(first.status, OuterMessage_Status.STATUS_OK);
      expect(first.hasPairingRequest(), isTrue);
      expect(first.pairingRequest.serviceName, 'atvremote');
      expect(first.pairingRequest.clientName, 'Living room phone');
      await client.close();
    });

    test('error_status_is_protocol_error', () async {
      final tv = await _ScriptedTv.start((message, socket) {
        _reply(socket, OuterMessage(status: OuterMessage_Status.STATUS_ERROR));
      });
      final client = _client(tv.port);

      await expectLater(
        client.start(clientName: 'Test phone'),
        throwsA(_pairingFailure(PairingFailure.protocolError)),
      );
    });

    test('unexpected_message_type_is_protocol_error', () async {
      final tv = await _ScriptedTv.start((message, socket) {
        _reply(
          socket,
          OuterMessage(
            status: OuterMessage_Status.STATUS_OK,
            configurationAck: ConfigurationAck(),
          ),
        );
      });
      final client = _client(tv.port);

      await expectLater(
        client.start(clientName: 'Test phone'),
        throwsA(_pairingFailure(PairingFailure.protocolError)),
      );
    });

    test('garbage_reply_is_protocol_error', () async {
      final tv = await _ScriptedTv.start((message, socket) {
        // A 3 byte frame whose payload is not valid protobuf.
        socket.add([3, 0xff, 0xff, 0xff]);
      });
      final client = _client(tv.port);

      await expectLater(
        client.start(clientName: 'Test phone'),
        throwsA(_pairingFailure(PairingFailure.protocolError)),
      );
    });

    test('peer_closing_mid_flow_is_connection_failed', () async {
      final tv = await _ScriptedTv.start((message, socket) => socket.destroy());
      final client = _client(tv.port);

      await expectLater(
        client.start(clientName: 'Test phone'),
        throwsA(_pairingFailure(PairingFailure.connectionFailed)),
      );
    });

    test('connection_dropped_before_code_is_connection_failed', () async {
      final tv = await _startTv();
      final client = _client(tv.pairingPort);
      await client.start(clientName: 'Test phone').timeout(_wait);
      final code = tv.displayedCode!;
      await tv.dropConnections();

      await expectLater(
        client.submitCode(code),
        throwsA(_pairingFailure(PairingFailure.connectionFailed)),
      );
    });

    test('submit_code_before_start_throws_state_error', () async {
      final tv = await _startTv();
      final client = _client(tv.pairingPort);

      await expectLater(client.submitCode('AABBCC'), throwsStateError);
    });

    test('start_twice_throws_state_error', () async {
      final tv = await _startTv();
      final client = _client(tv.pairingPort);
      await client.start(clientName: 'Test phone').timeout(_wait);

      await expectLater(
        client.start(clientName: 'Test phone'),
        throwsStateError,
      );
    });

    test('submit_code_after_success_throws_state_error', () async {
      final tv = await _startTv();
      final client = _client(tv.pairingPort);
      await client.start(clientName: 'Test phone').timeout(_wait);
      final code = tv.displayedCode!;
      await client.submitCode(code).timeout(_wait);

      await expectLater(client.submitCode(code), throwsStateError);
    });

    test('close_is_idempotent_in_every_state', () async {
      final tv = await _startTv();

      // Never started.
      final idle = _client(tv.pairingPort);
      await idle.close();
      await idle.close();

      // Waiting for the code.
      final waiting = _client(tv.pairingPort);
      await waiting.start(clientName: 'Test phone').timeout(_wait);
      await waiting.close();
      await waiting.close();
      await expectLater(waiting.submitCode('AABBCC'), throwsStateError);

      // A closed client cannot be started.
      await expectLater(
        idle.start(clientName: 'Test phone'),
        throwsStateError,
      );
    });

    test('close_during_start_fails_start_with_connection_failed', () async {
      final tv = await _ScriptedTv.start((message, socket) {});
      final client = _client(tv.port);
      final outcome = expectLater(
        client.start(clientName: 'Test phone'),
        throwsA(_pairingFailure(PairingFailure.connectionFailed)),
      );
      await tv.firstMessage;
      await client.close();

      await outcome;
    });
  });
}
