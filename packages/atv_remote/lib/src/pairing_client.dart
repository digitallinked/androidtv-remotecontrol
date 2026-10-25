import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:atv_remote/src/framing.dart';
import 'package:atv_remote/src/identity.dart';
import 'package:atv_remote/src/pairing_secret.dart';
import 'package:atv_remote/src/proto/polo.pb.dart';
import 'package:atv_remote/src/socket_connector.dart';

/// Why pairing failed.
enum PairingFailure {
  /// The TV could not be reached, the TLS handshake failed, or the TV closed
  /// the connection mid-flow.
  connectionFailed,

  /// The TV did not answer within the configured timeout.
  timeout,

  /// The TV rejected the secret. The code is now void; start a new session.
  badSecret,

  /// The TV sent an error status, an unexpected message, or malformed data.
  protocolError,

  /// The code typed by the user is malformed or fails its checksum. Nothing
  /// was sent; the session is still open for a corrected code.
  invalidCode,
}

/// Thrown by [PairingClient] when pairing cannot continue.
class PairingException implements Exception {
  /// Creates an exception for [reason] with an optional diagnostic [message].
  const PairingException(this.reason, [this.message]);

  /// What went wrong.
  final PairingFailure reason;

  /// Diagnostic detail for logs. Never contains key material or the code.
  final String? message;

  @override
  String toString() => message == null
      ? 'PairingException: ${reason.name}'
      : 'PairingException: ${reason.name} ($message)';
}

enum _Phase { idle, starting, awaitingCode, submitting, paired, ended }

/// Pairs this phone with a TV over the polo protocol on port 6467.
///
/// Flow (see androidtvremote2's `pairing.py`):
///
/// 1. [start] connects with the client certificate, negotiates the options
///    and returns once the TV displays the pairing code.
/// 2. [submitCode] takes the code the user read off the TV, proves knowledge
///    of it with a secret hash and completes once the TV acknowledges it.
///
/// A client is single use. After [submitCode] succeeds, fails with
/// [PairingFailure.badSecret], or any other failure other than
/// [PairingFailure.invalidCode], the session is over: create a new client to
/// try again. Calling methods out of order throws a [StateError]. [close] is
/// safe in every state and may be called any number of times.
///
/// A connection lost mid-flow (including the TV closing the socket) is
/// reported as [PairingFailure.connectionFailed], not as a protocol error:
/// the user's remedy is to retry, as with any network failure.
class PairingClient {
  /// Creates a client for the TV at [host]:[port].
  ///
  /// Every wait for the TV's reply is limited by [timeout]. [connector] is
  /// replaceable for tests.
  PairingClient({
    required this.host,
    required this.identity,
    this.port = 6467,
    this.connector = defaultSocketConnector,
    this.timeout = const Duration(seconds: 10),
  });

  /// TV address.
  final String host;

  /// TV pairing port.
  final int port;

  /// The client certificate and key presented to the TV.
  final ClientIdentity identity;

  /// Opens the TLS socket.
  final SocketConnector connector;

  /// Longest wait for the connection and for each reply.
  final Duration timeout;

  _Phase _phase = _Phase.idle;
  SecureSocket? _socket;
  // Cancelled in close().
  // ignore: cancel_subscriptions
  StreamSubscription<Uint8List>? _subscription;
  final FrameDecoder _decoder = FrameDecoder();
  final List<OuterMessage> _inbox = [];
  Completer<void>? _waiter;
  PairingException? _failure;
  late RsaPublicParts _serverParts;

  /// Connects to the TV and negotiates until it shows the pairing code.
  ///
  /// Throws a [StateError] unless this is the first call on a fresh client.
  Future<void> start({required String clientName}) async {
    if (_phase != _Phase.idle) {
      throw StateError('start() can only be called once, on a new client.');
    }
    _phase = _Phase.starting;
    try {
      await _connect();

      await _send(
        OuterMessage(
          status: OuterMessage_Status.STATUS_OK,
          pairingRequest: PairingRequest(
            serviceName: 'atvremote',
            clientName: clientName,
          ),
        ),
      );
      if (!(await _receive()).hasPairingRequestAck()) {
        _unexpected('pairing ack');
      }

      await _send(
        OuterMessage(
          status: OuterMessage_Status.STATUS_OK,
          options: Options(
            inputEncodings: [_encoding()],
            preferredRole: Options_RoleType.ROLE_TYPE_INPUT,
          ),
        ),
      );
      if (!(await _receive()).hasOptions()) _unexpected('options');

      await _send(
        OuterMessage(
          status: OuterMessage_Status.STATUS_OK,
          configuration: Configuration(
            encoding: _encoding(),
            clientRole: Options_RoleType.ROLE_TYPE_INPUT,
          ),
        ),
      );
      if (!(await _receive()).hasConfigurationAck()) {
        _unexpected('configuration ack');
      }
    } on Object {
      await close();
      rethrow;
    }
    if (_phase != _Phase.starting) throw _closedDuring();
    _phase = _Phase.awaitingCode;
  }

  /// Sends the secret derived from [code] and completes once the TV accepts
  /// it. Closes the connection afterwards.
  ///
  /// [code] is the six hex characters shown on the TV (any case). A code with
  /// a wrong checksum throws [PairingFailure.invalidCode] without sending
  /// anything, so the user can correct it and call again on this client.
  ///
  /// Throws a [StateError] unless [start] has completed and no earlier call
  /// has succeeded or failed (other than with [PairingFailure.invalidCode]).
  Future<void> submitCode(String code) async {
    if (_phase != _Phase.awaitingCode) {
      throw StateError(
        'submitCode() needs a started session that is waiting for the code.',
      );
    }
    final Uint8List secret;
    try {
      secret = computePairingSecret(
        client: identity.publicParts,
        server: _serverParts,
        code: code,
      );
    } on InvalidPairingCodeException catch (e) {
      throw PairingException(PairingFailure.invalidCode, e.message);
    }

    _phase = _Phase.submitting;
    try {
      await _send(
        OuterMessage(
          status: OuterMessage_Status.STATUS_OK,
          secret: Secret(secret: secret),
        ),
      );
      if (!(await _receive()).hasSecretAck()) _unexpected('secret ack');
    } on Object {
      await close();
      rethrow;
    }
    if (_phase != _Phase.submitting) throw _closedDuring();
    _phase = _Phase.paired;
    await close();
  }

  /// Drops the connection. Idempotent; safe in every state.
  ///
  /// A [start] or [submitCode] still waiting fails with
  /// [PairingFailure.connectionFailed].
  Future<void> close() async {
    if (_phase != _Phase.paired) _phase = _Phase.ended;
    _fail(const PairingException(PairingFailure.connectionFailed, 'closed'));
    final subscription = _subscription;
    _subscription = null;
    final socket = _socket;
    _socket = null;
    socket?.destroy();
    await subscription?.cancel();
  }

  Options_Encoding _encoding() => Options_Encoding(
    type: Options_Encoding_EncodingType.ENCODING_TYPE_HEXADECIMAL,
    symbolLength: 6,
  );

  Future<void> _connect() async {
    final SecureSocket socket;
    try {
      // No trusted roots: the TV's self-signed certificate is accepted by the
      // connector instead, and only our identity is loaded.
      final context = SecurityContext()
        ..useCertificateChainBytes(utf8.encode(identity.certificatePem))
        ..usePrivateKeyBytes(utf8.encode(identity.privateKeyPem));
      socket = await connector(host, port, context).timeout(timeout);
    } on TimeoutException {
      throw const PairingException(
        PairingFailure.connectionFailed,
        'connect timed out',
      );
    } on IOException catch (e) {
      // SocketException, HandshakeException, TlsException.
      throw PairingException(PairingFailure.connectionFailed, '$e');
    }
    if (_phase == _Phase.ended) {
      // close() ran while connecting.
      socket.destroy();
      throw const PairingException(PairingFailure.connectionFailed, 'closed');
    }

    final certificate = socket.peerCertificate;
    if (certificate == null) {
      socket.destroy();
      throw const PairingException(
        PairingFailure.connectionFailed,
        'the TV presented no certificate',
      );
    }
    try {
      _serverParts = rsaPublicPartsFromCertificateDer(certificate.der);
    } on Object catch (e) {
      // ArgumentError: not an RSA X.509 certificate.
      socket.destroy();
      throw PairingException(PairingFailure.protocolError, '$e');
    }

    _socket = socket;
    // A failing socket.done would otherwise be an unhandled async error.
    unawaited(socket.done.then<void>((_) {}, onError: (Object _) {}));
    _subscription = socket.listen(
      _onData,
      onError: (Object e) => _fail(
        PairingException(PairingFailure.connectionFailed, '$e'),
      ),
      onDone: () => _fail(
        const PairingException(
          PairingFailure.connectionFailed,
          'the TV closed the connection',
        ),
      ),
      cancelOnError: true,
    );
  }

  void _onData(Uint8List chunk) {
    try {
      for (final frame in _decoder.add(chunk)) {
        _inbox.add(OuterMessage.fromBuffer(frame));
      }
    } on Object catch (e) {
      // FormatException, FrameTooLargeException or a protobuf parse error.
      _fail(PairingException(PairingFailure.protocolError, 'bad frame: $e'));
      return;
    }
    _wake();
  }

  /// Records the first terminal failure and wakes anyone waiting.
  void _fail(PairingException failure) {
    _failure ??= failure;
    _wake();
  }

  void _wake() {
    final waiter = _waiter;
    _waiter = null;
    if (waiter != null && !waiter.isCompleted) waiter.complete();
  }

  Future<void> _send(OuterMessage message) async {
    final socket = _socket;
    if (socket == null || _failure != null) {
      throw _failure ??
          const PairingException(PairingFailure.connectionFailed, 'closed');
    }
    message.protocolVersion = 2;
    try {
      socket.add(encodeFrame(message.writeToBuffer()));
      await socket.flush().timeout(timeout);
    } on TimeoutException {
      throw const PairingException(PairingFailure.timeout, 'write timed out');
    } on Object catch (e) {
      throw _failure ?? PairingException(PairingFailure.connectionFailed, '$e');
    }
  }

  /// The next message from the TV, checked for an OK status.
  Future<OuterMessage> _receive() async {
    while (_inbox.isEmpty) {
      final failure = _failure;
      if (failure != null) throw failure;
      final waiter = _waiter = Completer<void>();
      try {
        await waiter.future.timeout(timeout);
      } on TimeoutException {
        _waiter = null;
        throw const PairingException(
          PairingFailure.timeout,
          'the TV did not answer in time',
        );
      }
    }
    final message = _inbox.removeAt(0);
    final status = message.status;
    if (status == OuterMessage_Status.STATUS_OK) return message;
    if (status == OuterMessage_Status.STATUS_BAD_SECRET) {
      throw const PairingException(
        PairingFailure.badSecret,
        'the TV rejected the secret',
      );
    }
    throw PairingException(
      PairingFailure.protocolError,
      'the TV answered with status ${status.name}',
    );
  }

  PairingException _closedDuring() =>
      _failure ??
      const PairingException(PairingFailure.connectionFailed, 'closed');

  Never _unexpected(String expected) => throw PairingException(
    PairingFailure.protocolError,
    'expected $expected from the TV',
  );
}
