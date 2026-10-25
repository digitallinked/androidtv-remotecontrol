import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:atv_remote/src/framing.dart';
import 'package:atv_remote/src/identity.dart';
import 'package:atv_remote/src/pairing_client.dart';
import 'package:atv_remote/src/pairing_secret.dart';
import 'package:atv_remote/src/proto/polo.pb.dart';
import 'package:atv_remote/src/proto/remotemessage.pb.dart';
import 'package:test/test.dart';

import 'fake_tv/fake_tv_identity.dart';
import 'fake_tv/fake_tv_server.dart';

const Duration _wait = Duration(seconds: 5);

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

  int get port => _server.port;

  /// The first message a client sent.
  Future<OuterMessage> get firstMessage => _first.future.timeout(_wait);

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
      onError: (Object _) {},
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
    test('pairs_successfully', () async {
      final tv = await _startTv();
      final client = _client(tv.pairingPort);

      await client.start(clientName: 'Test phone').timeout(_wait);
      final code = tv.displayedCode;
      expect(code, isNotNull);

      await client.submitCode(code!).timeout(_wait);

      // The TV now accepts this identity on the control port.
      final socket = await SecureSocket.connect(
        InternetAddress.loopbackIPv4,
        tv.remotePort,
        context: securityContextFor(_identity),
        onBadCertificate: (_) => true,
      ).timeout(_wait);
      addTearDown(socket.destroy);
      final decoder = FrameDecoder();
      final first = await socket.expand(decoder.add).first.timeout(_wait);
      expect(RemoteMessage.fromBuffer(first).hasRemoteConfigure(), isTrue);
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

    test('sends_pairing_request_first', () async {
      final tv = await _ScriptedTv.start((message, socket) {});
      final client = _client(
        tv.port,
        timeout: const Duration(milliseconds: 500),
      );
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
