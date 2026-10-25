import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:atv_remote/src/framing.dart';
import 'package:atv_remote/src/identity.dart';
import 'package:atv_remote/src/key_codes.dart';
import 'package:atv_remote/src/proto/remotemessage.pb.dart';
import 'package:atv_remote/src/remote_events.dart';
import 'package:atv_remote/src/socket_connector.dart';
import 'package:pointycastle/export.dart' show SHA256Digest;

/// Feature bitmask the client announces in `RemoteConfigure.code1` and
/// `RemoteSetActive.active` (androidtvremote2's value).
const int _featureCode = 622;

/// Describes this phone to the TV in the `RemoteConfigure` reply.
class DeviceInfo {
  /// Creates the description.
  const DeviceInfo({
    required this.model,
    required this.vendor,
    required this.packageName,
    required this.appVersion,
  });

  /// Device model, for example `Pixel 8`.
  final String model;

  /// Manufacturer, for example `Google`.
  final String vendor;

  /// Application id of this app.
  final String packageName;

  /// Version of this app.
  final String appVersion;
}

/// Thrown by `RemoteClient.connect` when no ready session could be opened.
class RemoteConnectException implements Exception {
  /// Creates an exception for [reason] with an optional diagnostic [message].
  const RemoteConnectException(this.reason, [this.message]);

  /// What went wrong: [RemoteCloseReason.certificateRejected] when the TV does
  /// not know this client (pair again), [RemoteCloseReason.networkError] when
  /// the TV could not be reached or answered too slowly,
  /// [RemoteCloseReason.remoteClosed] when it hung up mid-handshake, and
  /// [RemoteCloseReason.closedByClient] when `close` was called first.
  final RemoteCloseReason reason;

  /// Diagnostic detail for logs. Never contains key material.
  final String? message;

  @override
  String toString() => message == null
      ? 'RemoteConnectException: ${reason.name}'
      : 'RemoteConnectException: ${reason.name} ($message)';
}

enum _State { idle, connecting, handshaking, ready, closed }

/// The control channel to a paired TV (port 6466).
///
/// Flow (see androidtvremote2's `remote.py`):
///
/// 1. [connect] opens TLS with the client certificate. The TV sends
///    `RemoteConfigure`; the client answers with feature code 622 and its
///    [DeviceInfo]. The TV sends `RemoteSetActive`; the client answers
///    `active: 622`. On the first `RemoteSetActive` answered, [connect]
///    completes, [isReady] is true and [RemoteReady] is emitted.
/// 2. Like `remote.py`, every `RemoteConfigure` and `RemoteSetActive` is
///    answered whenever it arrives, in any order and as often as the TV
///    sends it, and `RemotePingRequest`s are always echoed.
/// 3. TV pushes (power, volume, current app, keyboard, errors) are handled
///    the same way during the handshake and once ready. Events for pushes
///    that arrive before ready are held back and emitted right after
///    [RemoteReady], so [RemoteReady] is always the first event.
/// 4. While ready, [sendKey], [launchAppLink] and [sendText] go to the TV,
///    and TV pushes arrive on [events].
///
/// A client is single use: after it closed (for any reason) create a new one.
///
/// [events] is a **broadcast** stream: a listener only sees events emitted
/// after it subscribed, so subscribe before calling [connect] if you need
/// everything ([connect] completing also signals readiness). The last event is
/// always one [RemoteClosed], emitted exactly once for every way a client can
/// end (TV hang-up, network error, ping timeout, [close]), and the stream is
/// closed right after it. When [connect] fails it throws and also emits that
/// [RemoteClosed], with the same reason as the exception.
///
/// Messages the client does not know are ignored silently.
class RemoteClient {
  /// Creates a client for the TV at [host]:[port].
  ///
  /// [connectTimeout] limits the connection (TCP and TLS together) and,
  /// separately, the wait for the TV to finish the configure/set-active
  /// handshake; running out is a [RemoteCloseReason.networkError].
  /// [connector] is replaceable for tests; when omitted, a connector bound to
  /// [connectTimeout] is used (see [socketConnectorWithTimeout]). A custom
  /// connector that delivers a socket after the timeout (or after [close])
  /// has the socket destroyed.
  ///
  /// Once ready, the connection is considered dead and closed with
  /// [RemoteCloseReason.pingTimeout] if no bytes arrive from the TV for
  /// [idleTimeout]. The TV pings every few seconds, so the 15 second default
  /// leaves room for a few lost pings.
  RemoteClient({
    required this.host,
    required this.identity,
    required this.deviceInfo,
    this.port = 6466,
    SocketConnector? connector,
    this.idleTimeout = const Duration(seconds: 15),
    this.connectTimeout = const Duration(seconds: 10),
  }) : _connector = connector ?? socketConnectorWithTimeout(connectTimeout);

  /// TV address.
  final String host;

  /// TV control port.
  final int port;

  /// The client certificate and key presented to the TV.
  final ClientIdentity identity;

  /// What the TV is told about this phone.
  final DeviceInfo deviceInfo;

  /// How long the TV may stay silent while ready.
  final Duration idleTimeout;

  /// Limit for connecting and for the handshake.
  final Duration connectTimeout;

  final SocketConnector _connector;
  final StreamController<RemoteEvent> _events =
      StreamController<RemoteEvent>.broadcast();
  final FrameDecoder _decoder = FrameDecoder();

  _State _state = _State.idle;
  SecureSocket? _socket;
  // Cancelled in _terminate().
  // ignore: cancel_subscriptions
  StreamSubscription<Uint8List>? _subscription;
  Future<void> _teardown = Future<void>.value();
  Completer<SecureSocket>? _pendingConnect;
  Completer<void>? _ready;
  Timer? _handshakeTimer;
  Timer? _idleTimer;
  bool _configured = false;
  Uint8List? _serverPublicKeySha256;
  // Events of TV pushes received before ready; emitted after RemoteReady.
  final List<RemoteEvent> _heldBack = [];

  // Counters from the latest IME message of the TV; sendText echoes them.
  int _imeCounter = 0;
  int _fieldCounter = 0;

  /// Events from the TV and about the connection (a broadcast stream, see the
  /// class documentation).
  Stream<RemoteEvent> get events => _events.stream;

  /// Whether the handshake finished and the connection is still open.
  bool get isReady => _state == _State.ready;

  /// SHA-256 over the TV certificate's RSA modulus followed by its exponent
  /// (unsigned big-endian, no leading zero), or `null` before the TLS
  /// handshake finished.
  ///
  /// Pin this per TV after pairing (trust on first use) and compare it on
  /// later connections.
  Uint8List? get serverPublicKeySha256 => _serverPublicKeySha256;

  /// Connects and completes once the TV finished the handshake.
  ///
  /// Throws a [RemoteConnectException] otherwise: `certificateRejected` when
  /// the TLS handshake fails or the TV closes the connection before the first
  /// `RemoteConfigure` (it does not know this client), `networkError` when it
  /// cannot be reached or is too slow, `remoteClosed` when it hangs up later
  /// in the handshake, `closedByClient` when [close] ran first. Throws a
  /// [StateError] if this client was already used.
  Future<void> connect() async {
    if (_state != _State.idle) {
      throw StateError('connect() can only be called once, on a new client.');
    }
    // No trusted roots: the TV's self-signed certificate is accepted by the
    // connector instead, and only our identity is loaded.
    final context = SecurityContext()
      ..useCertificateChainBytes(utf8.encode(identity.certificatePem))
      ..usePrivateKeyBytes(utf8.encode(identity.privateKeyPem));
    _state = _State.connecting;

    final SecureSocket socket;
    try {
      socket = await _open(context);
    } on RemoteConnectException catch (e) {
      _terminate(e.reason);
      rethrow;
    }
    if (_state != _State.connecting) {
      // close() won the race against a socket that had just arrived.
      socket.destroy();
      throw const RemoteConnectException(RemoteCloseReason.closedByClient);
    }

    final certificate = socket.peerCertificate;
    if (certificate == null) {
      socket.destroy();
      _terminate(RemoteCloseReason.networkError);
      throw const RemoteConnectException(
        RemoteCloseReason.networkError,
        'the TV presented no certificate',
      );
    }
    try {
      final parts = rsaPublicPartsFromCertificateDer(certificate.der);
      _serverPublicKeySha256 = SHA256Digest().process(
        Uint8List.fromList([...parts.modulus, ...parts.exponent]),
      );
    } on Object catch (e) {
      // ArgumentError: not an RSA X.509 certificate.
      socket.destroy();
      _terminate(RemoteCloseReason.networkError);
      throw RemoteConnectException(RemoteCloseReason.networkError, '$e');
    }

    _socket = socket;
    _state = _State.handshaking;
    final ready = _ready = Completer<void>();
    _handshakeTimer = Timer(
      connectTimeout,
      () => _terminate(RemoteCloseReason.networkError),
    );
    // A failing socket.done would otherwise be an unhandled async error.
    unawaited(
      socket.done.then<void>(
        (_) {},
        onError: (Object _) => _terminate(RemoteCloseReason.networkError),
      ),
    );
    _subscription = socket.listen(
      _onData,
      onError: _onSocketError,
      onDone: _onSocketDone,
      cancelOnError: true,
    );
    await ready.future;
  }

  /// Presses [keyCode] (an Android `KeyEvent` code, see [KeyCodes]).
  ///
  /// [direction] is a plain tap by default; send [KeyDirection.startLong] and
  /// later [KeyDirection.endLong] for press-and-hold.
  ///
  /// Throws a [StateError] unless the client is ready, and an
  /// [ArgumentError] for a code the protocol has no name for. A write that
  /// fails closes the client; [RemoteClosed] follows on [events].
  void sendKey(int keyCode, {KeyDirection direction = KeyDirection.short}) {
    _requireReady();
    final code = RemoteKeyCode.valueOf(keyCode);
    if (code == null) {
      throw ArgumentError.value(keyCode, 'keyCode', 'Unknown Android key code');
    }
    _write(
      RemoteMessage(
        remoteKeyInject: RemoteKeyInject(
          keyCode: code,
          direction: switch (direction) {
            KeyDirection.short => RemoteDirection.SHORT,
            KeyDirection.startLong => RemoteDirection.START_LONG,
            KeyDirection.endLong => RemoteDirection.END_LONG,
          },
        ),
      ),
    );
  }

  /// Asks the TV to open [link]: a deep link such as
  /// `https://www.netflix.com/title` or `market://launch?id=<package>`.
  ///
  /// Throws a [StateError] unless the client is ready.
  void launchAppLink(String link) {
    _requireReady();
    _write(
      RemoteMessage(
        remoteAppLinkLaunchRequest: RemoteAppLinkLaunchRequest(appLink: link),
      ),
    );
  }

  /// Types [text] into the TV's focused text field.
  ///
  /// Sent as an IME batch edit that inserts [text] with the cursor at its
  /// end, echoing the IME and field counters of the TV's latest IME message
  /// (0 until it sent one). Whether a real TV needs the counters incremented
  /// per edit is unverified.
  ///
  /// Throws a [StateError] unless the client is ready.
  void sendText(String text) {
    _requireReady();
    final cursor = math.max(0, text.length - 1);
    _write(
      RemoteMessage(
        remoteImeBatchEdit: RemoteImeBatchEdit(
          imeCounter: _imeCounter,
          fieldCounter: _fieldCounter,
          editInfo: [
            RemoteEditInfo(
              insert: 1,
              textFieldStatus: RemoteImeObject(
                value: text,
                start: cursor,
                end: cursor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Closes the connection. Idempotent; safe in every state.
  ///
  /// Emits [RemoteClosed] with [RemoteCloseReason.closedByClient] (unless the
  /// client had already ended) and closes [events]. A [connect] still running
  /// fails with [RemoteCloseReason.closedByClient].
  Future<void> close() async {
    final pending = _pendingConnect;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(
        const RemoteConnectException(RemoteCloseReason.closedByClient),
      );
    }
    _terminate(RemoteCloseReason.closedByClient);
    await _teardown;
  }

  // -------------------------------------------------------------- connecting

  /// Opens the socket, mapping every failure to a [RemoteConnectException].
  Future<SecureSocket> _open(SecurityContext context) async {
    final result = _pendingConnect = Completer<SecureSocket>();
    final timer = Timer(connectTimeout, () {
      if (!result.isCompleted) {
        result.completeError(
          TimeoutException('connecting timed out', connectTimeout),
        );
      }
    });
    // Future.timeout does not cancel the connector, and close() may stop
    // waiting too: a socket that arrives after that is destroyed instead of
    // being leaked as a live session.
    unawaited(
      Future<SecureSocket>.sync(
        () => _connector(host, port, context),
      ).then<void>(
        (socket) {
          if (result.isCompleted) {
            socket.destroy();
          } else {
            result.complete(socket);
          }
        },
        onError: (Object error, StackTrace stack) {
          if (!result.isCompleted) result.completeError(error, stack);
        },
      ),
    );
    try {
      return await result.future;
    } on RemoteConnectException {
      rethrow;
    } on TlsException catch (e) {
      // HandshakeException is a TlsException: the TV refused our certificate.
      throw RemoteConnectException(RemoteCloseReason.certificateRejected, '$e');
    } on Object catch (e) {
      // SocketException, TimeoutException and anything unexpected.
      throw RemoteConnectException(RemoteCloseReason.networkError, '$e');
    } finally {
      timer.cancel();
      if (identical(_pendingConnect, result)) _pendingConnect = null;
    }
  }

  // ---------------------------------------------------------------- receiving

  void _onData(Uint8List chunk) {
    if (_state == _State.closed) return;
    if (_state == _State.ready) _restartIdleTimer();
    final List<Uint8List> frames;
    try {
      frames = _decoder.add(chunk);
    } on Object {
      // FormatException or FrameTooLargeException: the stream lost sync.
      _terminate(RemoteCloseReason.networkError);
      return;
    }
    for (final frame in frames) {
      if (_state == _State.closed) return;
      final RemoteMessage message;
      try {
        message = RemoteMessage.fromBuffer(frame);
      } on Object {
        // One undecodable message: the framing is intact, so skip it.
        continue;
      }
      _handle(message);
    }
  }

  /// Handles one TV message the same way while handshaking and while ready
  /// (androidtvremote2's `remote.py` has no separate handshake phase).
  void _handle(RemoteMessage message) {
    if (_state != _State.handshaking && _state != _State.ready) return;
    if (message.hasRemotePingRequest()) {
      _write(
        RemoteMessage(
          remotePingResponse: RemotePingResponse(
            val1: message.remotePingRequest.val1,
          ),
        ),
      );
    } else if (message.hasRemoteConfigure()) {
      _configured = true;
      _write(
        RemoteMessage(
          remoteConfigure: RemoteConfigure(
            code1: _featureCode,
            deviceInfo: RemoteDeviceInfo(
              model: deviceInfo.model,
              vendor: deviceInfo.vendor,
              unknown1: 1,
              unknown2: '1',
              packageName: deviceInfo.packageName,
              appVersion: deviceInfo.appVersion,
            ),
          ),
        ),
      );
    } else if (message.hasRemoteSetActive()) {
      _write(
        RemoteMessage(remoteSetActive: RemoteSetActive(active: _featureCode)),
      );
      if (_state == _State.handshaking) _becomeReady();
    } else if (message.hasRemoteStart()) {
      _emitPush(PowerStateChanged(message.remoteStart.started));
    } else if (message.hasRemoteSetVolumeLevel()) {
      final volume = message.remoteSetVolumeLevel;
      _emitPush(
        VolumeChanged(volume.volumeLevel, volume.volumeMax, volume.volumeMuted),
      );
    } else if (message.hasRemoteImeKeyInject()) {
      final inject = message.remoteImeKeyInject;
      if (inject.hasTextFieldStatus()) {
        _fieldCounter = inject.textFieldStatus.counterField;
      }
      // Emitted every time the TV names an app, even an unchanged one.
      final package = inject.appInfo.appPackage;
      if (package.isNotEmpty) _emitPush(CurrentAppChanged(package));
    } else if (message.hasRemoteImeBatchEdit()) {
      final edit = message.remoteImeBatchEdit;
      _imeCounter = edit.imeCounter;
      _fieldCounter = edit.fieldCounter;
    } else if (message.hasRemoteImeShowRequest()) {
      _emitPush(const ImeShowRequested());
    } else if (message.hasRemoteError()) {
      final text = message.remoteError.toString().trim().replaceAll('\n', ' ');
      _emitPush(RemoteErrorReceived(text.isEmpty ? 'remote error' : text));
    }
    // Anything else (voice, audio devices, ...) is ignored.
  }

  /// The first `RemoteSetActive` was answered: the session is usable.
  void _becomeReady() {
    // The reply's write may have failed and closed the client.
    if (_state != _State.handshaking) return;
    _state = _State.ready;
    _handshakeTimer?.cancel();
    _handshakeTimer = null;
    _restartIdleTimer();
    _emit(const RemoteReady());
    _heldBack
      ..forEach(_emit)
      ..clear();
    final ready = _ready;
    if (ready != null && !ready.isCompleted) ready.complete();
  }

  /// Emits the event of a TV push, holding it back until ready.
  void _emitPush(RemoteEvent event) {
    if (_state == _State.ready) {
      _emit(event);
    } else {
      _heldBack.add(event);
    }
  }

  /// Whether the TV gave up on us during the handshake before its first
  /// `RemoteConfigure`: it does not know this client (R4).
  bool get _endedBeforeConfigure => !_configured && _state != _State.ready;

  void _onSocketDone() => _terminate(
    _endedBeforeConfigure
        // The TV says nothing to a client it does not know and just hangs up.
        ? RemoteCloseReason.certificateRejected
        : RemoteCloseReason.remoteClosed,
  );

  void _onSocketError(Object error) => _terminate(
    error is TlsException && _endedBeforeConfigure
        ? RemoteCloseReason.certificateRejected
        : RemoteCloseReason.networkError,
  );

  // ------------------------------------------------------------------ helpers

  void _requireReady() {
    if (_state == _State.ready) return;
    throw StateError(
      _state == _State.closed
          ? 'The remote client is closed.'
          : 'The remote client is not ready yet; await connect() first.',
    );
  }

  void _write(RemoteMessage message) {
    final socket = _socket;
    if (socket == null || _state == _State.closed) return;
    try {
      socket.add(encodeFrame(message.writeToBuffer()));
    } on Object {
      _terminate(RemoteCloseReason.networkError);
    }
  }

  void _emit(RemoteEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  void _restartIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(
      idleTimeout,
      () => _terminate(RemoteCloseReason.pingTimeout),
    );
  }

  /// Ends the client for [reason]. Only the first call has any effect.
  void _terminate(RemoteCloseReason reason) {
    if (_state == _State.closed) return;
    _state = _State.closed;
    _handshakeTimer?.cancel();
    _handshakeTimer = null;
    _idleTimer?.cancel();
    _idleTimer = null;
    _heldBack.clear();

    final ready = _ready;
    if (ready != null && !ready.isCompleted) {
      ready.completeError(RemoteConnectException(reason));
    }

    final subscription = _subscription;
    _subscription = null;
    final socket = _socket;
    _socket = null;
    socket?.destroy();
    _teardown = subscription?.cancel() ?? Future<void>.value();

    _emit(RemoteClosed(reason));
    unawaited(_events.close());
  }
}
