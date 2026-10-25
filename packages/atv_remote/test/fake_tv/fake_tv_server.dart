import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:atv_remote/src/framing.dart';
import 'package:atv_remote/src/identity.dart';
import 'package:atv_remote/src/pairing_secret.dart';
import 'package:atv_remote/src/proto/polo.pb.dart';
import 'package:atv_remote/src/proto/remotemessage.pb.dart';

import 'fake_tv_identity.dart';

/// An in-process stand-in for an Android TV running the Remote Service v2.
///
/// It speaks the real wire protocol (see androidtvremote2's `pairing.py` and
/// `remote.py`) over TLS on two loopback ports, so the pairing client, the
/// remote client and the connection manager can be tested without a TV.
///
/// * [pairingPort] runs the polo pairing flow and shows a random valid
///   [displayedCode]. A client that returns the right secret becomes paired,
///   identified by its certificate's public key.
/// * [remotePort] only talks to paired clients (unless `rejectUnknownClients`
///   is false). It sends `RemoteConfigure`, then (once the client answered)
///   any `initialPushes` and `RemoteSetActive`, then pings, and records what
///   the client injects. With `setActiveFirst` it sends `initialPushes`,
///   `RemoteSetActive` and `RemoteConfigure` straight away, in that order.
class FakeTvServer {
  FakeTvServer._(
    this._pairingServer,
    this._remoteServer, {
    required this.sendPings,
    required this.pingInterval,
    required this.rejectUnknownClients,
    required this.setActiveFirst,
    required List<RemoteMessage> initialPushes,
  }) : _initialPushes = List.unmodifiable(initialPushes);

  /// Lets [identity] get through the TLS handshake of every fake TV.
  ///
  /// Dart's server sockets reject unknown self-signed client certificates, so
  /// call this once for each client identity before it connects. Pairing is
  /// still required to use the remote port.
  static void trustClient(ClientIdentity identity) =>
      trustClientCertificate(identity);

  /// Binds both ports on the loopback interface and starts serving.
  ///
  /// [setActiveFirst] makes the TV send `RemoteSetActive` before
  /// `RemoteConfigure`. [initialPushes] are sent to every new remote client
  /// right before the TV's `RemoteSetActive`, i.e. before the client is
  /// ready (androidtvremote2's TVs push power, volume and current app early).
  static Future<FakeTvServer> start({
    bool sendPings = true,
    Duration pingInterval = const Duration(milliseconds: 200),
    bool rejectUnknownClients = true,
    bool setActiveFirst = false,
    List<RemoteMessage> initialPushes = const [],
  }) async {
    final context = fakeTvServerContext;
    final pairingServer = await SecureServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
      context,
      requestClientCertificate: true,
    );
    final remoteServer = await SecureServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
      context,
      requestClientCertificate: true,
    );
    final tv = FakeTvServer._(
      pairingServer,
      remoteServer,
      sendPings: sendPings,
      pingInterval: pingInterval,
      rejectUnknownClients: rejectUnknownClients,
      setActiveFirst: setActiveFirst,
      initialPushes: initialPushes,
    );
    // Handshake failures arrive as stream errors; a fake TV just ignores them.
    pairingServer.listen(tv._onPairingSocket, onError: (Object _) {});
    remoteServer.listen(tv._onRemoteSocket, onError: (Object _) {});
    return tv;
  }

  /// Whether to ping connected clients every [pingInterval].
  final bool sendPings;

  /// Time between pings.
  final Duration pingInterval;

  /// Whether clients that have not paired are disconnected on the remote port.
  final bool rejectUnknownClients;

  /// Whether `RemoteSetActive` is sent before `RemoteConfigure`.
  final bool setActiveFirst;

  final List<RemoteMessage> _initialPushes;

  final SecureServerSocket _pairingServer;
  final SecureServerSocket _remoteServer;

  final Set<String> _pairedKeys = {};
  final Set<SecureSocket> _pairingSockets = {};
  final Set<_RemoteClient> _remoteClients = {};
  _RemoteClient? _lastPingedClient;
  final List<Completer<void>> _activeWaiters = [];
  int _pingCounter = 0;
  bool _closed = false;

  String? _displayedCode;
  final List<int> _receivedKeyCodes = [];
  final List<RemoteDirection> _receivedKeyDirections = [];
  final List<String> _receivedAppLinks = [];
  String _receivedText = '';
  RemoteConfigure? _receivedConfigure;
  int? _receivedActiveCode;
  RemoteImeBatchEdit? _receivedImeBatchEdit;
  int _answeredPings = 0;
  int _configureReplies = 0;
  int _setActiveReplies = 0;

  /// Port of the pairing (polo) service.
  int get pairingPort => _pairingServer.port;

  /// Port of the remote control service.
  int get remotePort => _remoteServer.port;

  /// The code "shown on the TV" for the current pairing attempt, as six
  /// upper-case hex characters, or `null` before the TV reached that step.
  String? get displayedCode => _displayedCode;

  /// Android key codes injected by clients, in order, including the
  /// start and end of long presses.
  List<int> get receivedKeyCodes => List.unmodifiable(_receivedKeyCodes);

  /// Directions matching [receivedKeyCodes] one to one.
  List<RemoteDirection> get receivedKeyDirections =>
      List.unmodifiable(_receivedKeyDirections);

  /// App links that clients asked the TV to launch, in order.
  List<String> get receivedAppLinks => List.unmodifiable(_receivedAppLinks);

  /// The text of the most recent `RemoteImeBatchEdit`, or an empty string.
  String get receivedText => _receivedText;

  /// The `RemoteConfigure` the client answered the TV's with, or `null`.
  RemoteConfigure? get receivedConfigure => _receivedConfigure;

  /// The `active` value of the client's `RemoteSetActive` reply, or `null`.
  int? get receivedActiveCode => _receivedActiveCode;

  /// The most recent `RemoteImeBatchEdit` in full (counters included), or
  /// `null`.
  RemoteImeBatchEdit? get receivedImeBatchEdit => _receivedImeBatchEdit;

  /// How many pings (all clients, all time) have been answered.
  int get answeredPingCount => _answeredPings;

  /// How many `RemoteConfigure` replies (all clients, all time) arrived.
  int get configureReplyCount => _configureReplies;

  /// How many `RemoteSetActive` replies (all clients, all time) arrived.
  int get setActiveReplyCount => _setActiveReplies;

  /// Whether the most recently sent ping has been answered.
  ///
  /// `false` before any ping and after a ping the client ignored. A ping
  /// sent only moments ago is still in flight, so while it is, the answer for
  /// the ping before it is reported instead; that keeps polling free of
  /// timing races on a fast loopback.
  ///
  /// `false` once that client has closed (it hung up, was dropped, or was
  /// closed for ignoring pings), so a stale answer cannot leak into a test
  /// that has already lost its connection.
  bool get clientAnsweredLastPing {
    final client = _lastPingedClient;
    if (client == null || client.isClosed) return false;
    return client.answeredLastPing(pingInterval);
  }

  /// Completes when a remote client has finished the `RemoteSetActive`
  /// exchange, i.e. the TV considers it ready (immediately if one already
  /// has).
  ///
  /// A client's own `connect()` may complete a moment before the fake has
  /// processed that client's `RemoteSetActive`; await this before relying on
  /// server pushes such as [sendVolume]. Throws a [TimeoutException] after
  /// [timeout].
  Future<void> waitForActiveClient({
    Duration timeout = const Duration(seconds: 5),
  }) {
    if (_remoteClients.any((client) => client.active)) return Future.value();
    final waiter = Completer<void>();
    _activeWaiters.add(waiter);
    return waiter.future.timeout(
      timeout,
      onTimeout: () {
        _activeWaiters.remove(waiter);
        throw TimeoutException('No remote client became active', timeout);
      },
    );
  }

  void _clientBecameActive() {
    final waiters = _activeWaiters.toList();
    _activeWaiters.clear();
    for (final waiter in waiters) {
      if (!waiter.isCompleted) waiter.complete();
    }
  }

  /// Sends [message] to every active remote client.
  void sendMessage(RemoteMessage message) => _broadcast(message);

  /// Sends all [messages] to every active remote client in a single socket
  /// write, so they reach the client in one chunk.
  void sendMessages(List<RemoteMessage> messages) {
    final bytes = BytesBuilder(copy: false);
    for (final message in messages) {
      bytes.add(encodeFrame(message.writeToBuffer()));
    }
    final chunk = bytes.takeBytes();
    for (final client in _remoteClients) {
      if (client.active) client.sendRaw(chunk);
    }
  }

  /// Sends another `RemoteConfigure` to every active remote client, as a
  /// TV may at any time.
  void resendConfigure() => _broadcast(_RemoteClient.configureMessage);

  /// Sends another `RemoteSetActive` to every active remote client, as a TV
  /// may at any time.
  void resendSetActive() => _broadcast(_RemoteClient.setActiveMessage);

  /// Sends a volume update to every active remote client.
  void sendVolume({
    required int level,
    required int max,
    required bool muted,
  }) => _broadcast(
    RemoteMessage(
      remoteSetVolumeLevel: RemoteSetVolumeLevel(
        volumeLevel: level,
        volumeMax: max,
        volumeMuted: muted,
      ),
    ),
  );

  /// Tells every active remote client which app is in the foreground.
  void sendCurrentApp(String package) => _broadcast(
    RemoteMessage(
      remoteImeKeyInject: RemoteImeKeyInject(
        appInfo: RemoteAppInfo(appPackage: package),
      ),
    ),
  );

  /// Tells every active remote client that a text field wants the keyboard.
  void sendImeShow() => _broadcast(
    RemoteMessage(remoteImeShowRequest: RemoteImeShowRequest()),
  );

  /// Reports the screen state (`true` is on) to every active remote client.
  // The positional bool mirrors the specified API.
  // ignore: avoid_positional_boolean_parameters
  void setPowerOn(bool on) => _broadcast(
    RemoteMessage(remoteStart: RemoteStart(started: on)),
  );

  /// Destroys every client connection on both ports but keeps listening.
  Future<void> dropConnections() async {
    for (final socket in _pairingSockets.toList()) {
      socket.destroy();
    }
    _pairingSockets.clear();
    for (final client in _remoteClients.toList()) {
      client.close();
    }
    _remoteClients.clear();
    _lastPingedClient = null;
  }

  /// Forgets every paired client, as if the TV had been factory reset.
  void forgetClients() => _pairedKeys.clear();

  /// Stops listening and drops all connections.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await dropConnections();
    await _pairingServer.close();
    await _remoteServer.close();
  }

  // ---------------------------------------------------------------- pairing

  void _onPairingSocket(SecureSocket socket) {
    _pairingSockets.add(socket);
    // A write after the peer reset the connection fails `done`; without a
    // handler that would surface as an unhandled async error.
    unawaited(socket.done.then<void>((_) {}, onError: (Object _) {}));
    final decoder = FrameDecoder();
    var stage = _PairingStage.request;
    final RsaPublicParts clientParts;
    try {
      clientParts = _peerParts(socket);
    } on Object {
      socket.destroy();
      _pairingSockets.remove(socket);
      return;
    }

    void reply(OuterMessage message) {
      message.protocolVersion = 2;
      socket.add(encodeFrame(message.writeToBuffer()));
    }

    void handle(OuterMessage message) {
      switch (stage) {
        case _PairingStage.request when message.hasPairingRequest():
          stage = _PairingStage.options;
          reply(
            OuterMessage(
              status: OuterMessage_Status.STATUS_OK,
              pairingRequestAck: PairingRequestAck(serverName: 'FakeTV'),
            ),
          );
        case _PairingStage.options when message.hasOptions():
          stage = _PairingStage.configuration;
          reply(
            OuterMessage(
              status: OuterMessage_Status.STATUS_OK,
              options: Options(
                inputEncodings: [
                  Options_Encoding(
                    type:
                        Options_Encoding_EncodingType.ENCODING_TYPE_HEXADECIMAL,
                    symbolLength: 6,
                  ),
                ],
                preferredRole: Options_RoleType.ROLE_TYPE_INPUT,
              ),
            ),
          );
        case _PairingStage.configuration when message.hasConfiguration():
          stage = _PairingStage.secret;
          _displayedCode = _generateCode(
            client: clientParts,
            server: fakeTvIdentity.publicParts,
          );
          reply(
            OuterMessage(
              status: OuterMessage_Status.STATUS_OK,
              configurationAck: ConfigurationAck(),
            ),
          );
        case _PairingStage.secret when message.hasSecret():
          final code = _displayedCode;
          final expected = code == null
              ? null
              : computePairingSecret(
                  client: clientParts,
                  server: fakeTvIdentity.publicParts,
                  code: code,
                );
          if (expected != null && _sameBytes(message.secret.secret, expected)) {
            stage = _PairingStage.done;
            _pairedKeys.add(_keyId(clientParts));
            reply(
              OuterMessage(
                status: OuterMessage_Status.STATUS_OK,
                secretAck: SecretAck(secret: expected),
              ),
            );
          } else {
            reply(OuterMessage(status: OuterMessage_Status.STATUS_BAD_SECRET));
          }
        case _:
          // Out-of-order or unsupported message: ignore it.
          break;
      }
    }

    socket.listen(
      (chunk) {
        try {
          for (final frame in decoder.add(chunk)) {
            handle(OuterMessage.fromBuffer(frame));
          }
        } on Object {
          socket.destroy();
        }
      },
      onError: (Object _) => socket.destroy(),
      onDone: () {
        _pairingSockets.remove(socket);
        socket.destroy();
      },
    );
  }

  /// Picks a random 4-hex suffix and the one checksum byte that makes the
  /// code valid for [client] and [server].
  static String _generateCode({
    required RsaPublicParts client,
    required RsaPublicParts server,
  }) {
    final random = Random.secure();
    final suffix = random.nextInt(0x10000).toRadixString(16).padLeft(4, '0');
    for (var prefix = 0; prefix < 256; prefix++) {
      final code = prefix.toRadixString(16).padLeft(2, '0') + suffix;
      try {
        computePairingSecret(client: client, server: server, code: code);
        return code.toUpperCase();
      } on InvalidPairingCodeException {
        // Wrong checksum byte; try the next one.
      }
    }
    throw StateError('No checksum byte matched; unreachable.');
  }

  // ----------------------------------------------------------------- remote

  void _onRemoteSocket(SecureSocket socket) {
    unawaited(socket.done.then<void>((_) {}, onError: (Object _) {}));
    final RsaPublicParts parts;
    try {
      parts = _peerParts(socket);
    } on Object {
      socket.destroy();
      return;
    }
    if (rejectUnknownClients && !_pairedKeys.contains(_keyId(parts))) {
      socket.destroy();
      return;
    }
    final client = _RemoteClient(this, socket);
    _remoteClients.add(client);
    client.start();
  }

  void _broadcast(RemoteMessage message) {
    for (final client in _remoteClients) {
      if (client.active) client.send(message);
    }
  }

  void _handleClientMessage(RemoteMessage message) {
    if (message.hasRemoteConfigure()) {
      _configureReplies++;
      _receivedConfigure = message.remoteConfigure;
    } else if (message.hasRemoteSetActive()) {
      _setActiveReplies++;
      _receivedActiveCode = message.remoteSetActive.active;
    } else if (message.hasRemoteKeyInject()) {
      final inject = message.remoteKeyInject;
      _receivedKeyCodes.add(inject.keyCode.value);
      _receivedKeyDirections.add(inject.direction);
    } else if (message.hasRemoteAppLinkLaunchRequest()) {
      _receivedAppLinks.add(message.remoteAppLinkLaunchRequest.appLink);
    } else if (message.hasRemoteImeBatchEdit()) {
      _receivedImeBatchEdit = message.remoteImeBatchEdit;
      // androidtvremote2 sends the typed text in
      // edit_info[].text_field_status.value; the last entry wins.
      final edits = message.remoteImeBatchEdit.editInfo;
      if (edits.isNotEmpty) {
        _receivedText = edits.last.textFieldStatus.value;
      }
    }
    // Everything else (voice, volume adjust, ...) is ignored.
  }

  static RsaPublicParts _peerParts(SecureSocket socket) {
    final certificate = socket.peerCertificate;
    if (certificate == null) throw StateError('Client sent no certificate.');
    return rsaPublicPartsFromCertificateDer(certificate.der);
  }

  static String _keyId(RsaPublicParts parts) =>
      parts.modulus.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static bool _sameBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

enum _PairingStage { request, options, configuration, secret, done }

/// One client connected to the remote port.
class _RemoteClient {
  _RemoteClient(this._tv, this._socket);

  final FakeTvServer _tv;
  final SecureSocket _socket;
  final FrameDecoder _decoder = FrameDecoder();

  bool _configured = false;
  bool active = false;
  bool _closed = false;
  Timer? _pingTimer;

  int _lastPing = 0;
  int _previousPing = 0;
  int _answeredUpTo = 0;
  int _consecutiveUnanswered = 0;
  DateTime _lastPingAt = DateTime.fromMillisecondsSinceEpoch(0);

  void start() {
    _socket.listen(
      (chunk) {
        try {
          for (final frame in _decoder.add(chunk)) {
            _handle(RemoteMessage.fromBuffer(frame));
          }
        } on Object {
          close();
        }
      },
      onError: (Object _) => close(),
      onDone: close,
    );
    if (_tv.setActiveFirst) {
      _sendPushesAndSetActive();
      send(configureMessage);
    } else {
      send(configureMessage);
    }
  }

  static final RemoteMessage configureMessage = RemoteMessage(
    remoteConfigure: RemoteConfigure(
      code1: 622,
      deviceInfo: RemoteDeviceInfo(
        model: 'FakeTV',
        vendor: 'Fake',
        unknown1: 1,
        unknown2: '1',
        packageName: 'com.fake.tv',
        appVersion: '1.0.0',
      ),
    ),
  );

  static final RemoteMessage setActiveMessage = RemoteMessage(
    remoteSetActive: RemoteSetActive(active: 622),
  );

  void _sendPushesAndSetActive() {
    _tv._initialPushes.forEach(send);
    send(setActiveMessage);
  }

  void _handle(RemoteMessage message) {
    if (message.hasRemoteConfigure()) {
      // Every reply is recorded; only the first one drives the handshake.
      _tv._handleClientMessage(message);
      if (_configured) return;
      _configured = true;
      if (!_tv.setActiveFirst) _sendPushesAndSetActive();
    } else if (message.hasRemoteSetActive()) {
      _tv._handleClientMessage(message);
      if (active) return;
      active = true;
      _tv._clientBecameActive();
      if (_tv.sendPings) {
        _pingTimer = Timer.periodic(_tv.pingInterval, (_) => _ping());
      }
    } else if (message.hasRemotePingResponse()) {
      final n = message.remotePingResponse.val1;
      if (n > _answeredUpTo) {
        _answeredUpTo = n;
        _tv._answeredPings++;
      }
    } else {
      _tv._handleClientMessage(message);
    }
  }

  void _ping() {
    if (_lastPing > _answeredUpTo) {
      _consecutiveUnanswered++;
      if (_consecutiveUnanswered >= 3) {
        close();
        return;
      }
    } else {
      _consecutiveUnanswered = 0;
    }
    _previousPing = _lastPing;
    _lastPing = ++_tv._pingCounter;
    _lastPingAt = DateTime.now();
    _tv._lastPingedClient = this;
    send(
      RemoteMessage(remotePingRequest: RemotePingRequest(val1: _lastPing)),
    );
  }

  bool answeredLastPing(Duration pingInterval) {
    if (_lastPing == 0) return false;
    if (_answeredUpTo >= _lastPing) return true;
    final age = DateTime.now().difference(_lastPingAt);
    if (age < pingInterval ~/ 2) {
      // Still in flight: judge the ping before it.
      return _previousPing != 0 && _answeredUpTo >= _previousPing;
    }
    return false;
  }

  void send(RemoteMessage message) =>
      sendRaw(encodeFrame(message.writeToBuffer()));

  void sendRaw(List<int> bytes) {
    if (_closed) return;
    try {
      _socket.add(bytes);
    } on Object {
      close();
    }
  }

  bool get isClosed => _closed;

  void close() {
    if (_closed) return;
    _closed = true;
    active = false;
    _pingTimer?.cancel();
    _tv._remoteClients.remove(this);
    if (_tv._lastPingedClient == this) _tv._lastPingedClient = null;
    _socket.destroy();
  }
}
