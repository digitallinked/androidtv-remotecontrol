import 'dart:async';
import 'dart:typed_data';

import 'package:atv_remote/atv_remote.dart';

import 'test_devices.dart';

/// How a [FakeRemoteClient]'s `connect` ends.
enum FakeConnect {
  /// The handshake finishes: ready, and `RemoteReady` is emitted.
  succeed,

  /// The TV can't be reached (`RemoteCloseReason.networkError`).
  networkError,

  /// The TV refuses this phone's certificate
  /// (`RemoteCloseReason.certificateRejected`).
  certificateRejected,

  /// `connect` never finishes on its own; it fails once `close` is called.
  hang,
}

/// A deterministic [RemoteClient] for app tests: no sockets, works under
/// `fakeAsync` and `testWidgets`.
///
/// It uses `implements`: the private members of the library's
/// `RemoteClient` aren't part of its interface, so only the public API has to
/// be provided here. `fakes_contract_test.dart` pins where it must behave like
/// the real client.
class FakeRemoteClient implements RemoteClient {
  /// Creates a client whose `connect` ends as [outcome] and which presents
  /// [serverKey] as the TV key once ready.
  FakeRemoteClient({
    required this.host,
    required this.port,
    required this.identity,
    this.outcome = FakeConnect.succeed,
    List<int> serverKey = testServerKey,
  }) : _serverKey = Uint8List.fromList(serverKey);

  @override
  final String host;

  @override
  final int port;

  @override
  final ClientIdentity identity;

  /// How [connect] ends.
  final FakeConnect outcome;

  final Uint8List _serverKey;

  @override
  DeviceInfo get deviceInfo => const DeviceInfo(
    model: 'Test',
    vendor: 'Test',
    packageName: 'test',
    appVersion: '0',
  );

  @override
  Duration get idleTimeout => const Duration(seconds: 15);

  @override
  Duration get connectTimeout => const Duration(seconds: 10);

  /// Keys sent while ready, in order.
  final List<(int, KeyDirection)> sentKeys = [];

  /// Deep links sent while ready, in order.
  final List<String> sentLinks = [];

  /// Texts sent while ready, in order.
  final List<String> sentTexts = [];

  final StreamController<RemoteEvent> _events =
      StreamController<RemoteEvent>.broadcast();
  final Completer<void> _hung = Completer<void>();
  // Pushes received before ready; emitted right after RemoteReady.
  final List<RemoteEvent> _heldBack = [];
  bool _connectCalled = false;
  bool _tlsPassed = false;
  bool _ready = false;
  bool _closed = false;

  /// Whether the client ended: [close] or [drop] was called, or [connect]
  /// failed.
  bool get closed => _closed;

  @override
  Stream<RemoteEvent> get events => _events.stream;

  @override
  bool get isReady => _ready;

  @override
  Uint8List? get serverPublicKeySha256 => _tlsPassed ? _serverKey : null;

  @override
  Future<void> connect() async {
    // A closed client is used up, like the real one.
    if (_connectCalled || _closed) {
      throw StateError('connect() can only be called once, on a new client.');
    }
    _connectCalled = true;
    await Future<void>.value();
    if (_closed) {
      throw const RemoteConnectException(RemoteCloseReason.closedByClient);
    }
    switch (outcome) {
      case FakeConnect.succeed:
        // The TLS handshake passed: the key is known before the client is
        // ready, as in RemoteClient.
        _tlsPassed = true;
        _ready = true;
        _events.add(const RemoteReady());
        _heldBack
          ..forEach(_events.add)
          ..clear();
      case FakeConnect.networkError:
        _fail(RemoteCloseReason.networkError);
      case FakeConnect.certificateRejected:
        _fail(RemoteCloseReason.certificateRejected);
      case FakeConnect.hang:
        await _hung.future;
        throw const RemoteConnectException(RemoteCloseReason.closedByClient);
    }
  }

  Never _fail(RemoteCloseReason reason) {
    _end(reason);
    throw RemoteConnectException(reason);
  }

  /// Emits [event] as if the TV pushed it. Before the client is ready the
  /// event is held back and emitted right after `RemoteReady`, like the real
  /// client; after it ended, the event is dropped.
  void push(RemoteEvent event) {
    if (_closed) return;
    if (_ready) {
      _events.add(event);
    } else {
      _heldBack.add(event);
    }
  }

  /// Ends the connection as if the TV went away.
  void drop([RemoteCloseReason reason = RemoteCloseReason.remoteClosed]) =>
      _end(reason);

  @override
  void sendKey(int keyCode, {KeyDirection direction = KeyDirection.short}) {
    _requireReady();
    if (!isSupportedKeyCode(keyCode)) {
      throw ArgumentError.value(keyCode, 'keyCode', 'Unknown Android key code');
    }
    sentKeys.add((keyCode, direction));
  }

  @override
  void launchAppLink(String link) {
    _requireReady();
    sentLinks.add(link);
  }

  @override
  void sendText(String text) {
    _requireReady();
    sentTexts.add(text);
  }

  @override
  Future<void> close() async {
    if (!_hung.isCompleted) _hung.complete();
    _end(RemoteCloseReason.closedByClient);
  }

  void _requireReady() {
    if (!_ready) throw StateError('The client is not ready.');
  }

  void _end(RemoteCloseReason reason) {
    if (_closed) return;
    _closed = true;
    _ready = false;
    _heldBack.clear();
    _events
      ..add(RemoteClosed(reason))
      ..close().ignore();
  }
}

/// Hands out [FakeRemoteClient]s; [create] is a `RemoteClientFactory`.
class FakeRemoteClients {
  /// Creates a factory whose clients present `serverKey` as the TV key.
  FakeRemoteClients({this._serverKey = testServerKey});

  final List<int> _serverKey;

  /// The outcome of the clients created for a host; hosts not listed use
  /// [defaultOutcome].
  final Map<String, FakeConnect> outcomes = {};

  /// The outcome for hosts that aren't in [outcomes].
  FakeConnect defaultOutcome = FakeConnect.succeed;

  /// Every client created so far, in order.
  final List<FakeRemoteClient> created = [];

  /// Creates a client for [host]; matches `RemoteClientFactory`.
  RemoteClient create({
    required String host,
    required int port,
    required ClientIdentity identity,
  }) {
    final client = FakeRemoteClient(
      host: host,
      port: port,
      identity: identity,
      outcome: outcomes[host] ?? defaultOutcome,
      serverKey: _serverKey,
    );
    created.add(client);
    return client;
  }
}
