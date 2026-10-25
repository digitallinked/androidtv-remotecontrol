// Named parameters cannot be private, so the constructor cannot use
// initializing formals for the private fields.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:typed_data';

import 'package:atv_remote/src/backoff.dart';
import 'package:atv_remote/src/key_codes.dart';
import 'package:atv_remote/src/remote_client.dart';
import 'package:atv_remote/src/remote_events.dart';
import 'package:meta/meta.dart';

/// Where a [TvConnection] stands. The UI enables its controls only for
/// [connected].
enum ConnectionStatus {
  /// Not connected and not trying: the initial state, and the state after
  /// `TvConnection.dispose`.
  disconnected,

  /// The first connection attempt of a `TvConnection.connect` is running.
  connecting,

  /// The TV finished the handshake: commands can be sent.
  connected,

  /// The connection was lost (or the TV was unreachable on the first
  /// connect). Either an attempt is running or one is scheduled after a
  /// backoff delay.
  reconnecting,

  /// The TV does not accept this phone's certificate
  /// (`RemoteCloseReason.certificateRejected`), or its key no longer matches
  /// the pinned one (`RemoteCloseReason.serverKeyChanged`): pair again. No
  /// attempt is made until `TvConnection.connect` is called.
  needsPairing,

  /// Every reconnect attempt failed. A resume, a network change or
  /// `TvConnection.connect` tries again.
  offline,
}

/// A snapshot of a [TvConnection].
@immutable
class TvConnectionState {
  /// Creates a state.
  const TvConnectionState({
    required this.status,
    this.attempt = 0,
    this.lastError,
  });

  /// The current phase.
  final ConnectionStatus status;

  /// Reconnect attempts since the connection was last [ConnectionStatus
  /// .connected] (or since a resume restarted the count): the one running or
  /// waiting while [ConnectionStatus.reconnecting], the last one made while
  /// [ConnectionStatus.offline], otherwise `0`.
  final int attempt;

  /// Why the connection was lost or could not be made, or `null` while
  /// healthy.
  final RemoteCloseReason? lastError;

  @override
  bool operator ==(Object other) =>
      other is TvConnectionState &&
      other.status == status &&
      other.attempt == attempt &&
      other.lastError == lastError;

  @override
  int get hashCode => Object.hash(status, attempt, lastError);

  @override
  String toString() =>
      'TvConnectionState(${status.name}, attempt: $attempt, '
      'lastError: ${lastError?.name})';
}

/// Thrown by the command methods of `TvConnection` while the connection is
/// not [ConnectionStatus.connected].
class NotConnectedException implements Exception {
  /// Creates the exception.
  const NotConnectedException();

  @override
  String toString() => 'NotConnectedException: the TV is not connected';
}

/// Keeps a control connection to one TV alive.
///
/// Wraps a [RemoteClient] (a new one from the factory for every attempt),
/// exposes a truthful [states] stream and reconnects with [Backoff] when the
/// connection is lost.
///
/// Transitions:
///
/// * [connect]: `connecting`, then `connected` once the client is ready.
/// * Lost while `connected` (TV hung up, ping timeout, network error):
///   `reconnecting`, attempt 1, 2, ... after the [Backoff] delays. Success
///   gives `connected` and resets the backoff and the attempt count.
/// * A first [connect] that cannot reach the TV (network error, or the TV
///   hung up mid-handshake) enters the same loop: the TV may be waking up.
/// * [Backoff.next] returning `null` gives `offline` (keeping the attempt
///   count and the last error).
/// * `certificateRejected` at any point gives `needsPairing`; nothing more is
///   tried until [connect] is called again.
/// * A ready client whose TV key the `verifyServerKey` callback rejects is
///   closed and gives `needsPairing` with `serverKeyChanged`, never
///   `connected`; nothing more is tried until [connect] is called again.
/// * [notifyAppResumed] and [notifyNetworkChanged] retry at once from
///   `reconnecting` and `offline`, restarting the backoff and the attempt
///   count; an attempt still running (possibly hanging until its connect
///   timeout) is abandoned for the fresh one. In every other state they do
///   nothing.
/// * [disconnect] closes the client and cancels any retry, ending in
///   `disconnected`; unlike [dispose], a later [connect] starts afresh.
/// * [dispose] ends everything in `disconnected`, for good.
///
/// A failed `RemoteClient.connect` both throws and emits `RemoteClosed`; each
/// failure is handled exactly once, from the exception. A `RemoteClosed` only
/// counts as a lost connection for a client that had become ready.
class TvConnection {
  /// Creates a connection to the TV at [host].
  ///
  /// [clientFactory] must return a **new** `RemoteClient` for the given host
  /// on every call. [backoff] defaults to 1 s, 2 s, 4 s ... 30 s, six
  /// attempts. Before every reconnect attempt (not the first [connect]),
  /// [reResolveHost] is awaited if given (typically an mDNS lookup of the
  /// TV): a non-null result replaces the host from then on; errors and
  /// `null` keep the old host, and so does a lookup that takes longer than
  /// [reResolveTimeout].
  ///
  /// [verifyServerKey] pins the TV's identity (trust on first use): on every
  /// attempt, once the client is ready and before `connected` is emitted, it
  /// gets the client's `RemoteClient.serverPublicKeySha256` (compare it with
  /// the `PairingClient.serverPublicKeySha256` stored at pairing). If it
  /// returns `false` (or throws), that client is closed without any command
  /// or event getting through, and the state becomes `needsPairing` with
  /// [RemoteCloseReason.serverKeyChanged]. When omitted, every key is
  /// accepted.
  TvConnection({
    required String host,
    required RemoteClient Function(String host) clientFactory,
    Backoff? backoff,
    Future<String?> Function()? reResolveHost,
    Duration reResolveTimeout = const Duration(seconds: 5),
    bool Function(Uint8List serverKeySha256)? verifyServerKey,
  }) : _host = host,
       _clientFactory = clientFactory,
       _backoff = backoff ?? Backoff(),
       _reResolveHost = reResolveHost,
       _reResolveTimeout = reResolveTimeout,
       _verifyServerKey = verifyServerKey;

  String _host;
  final RemoteClient Function(String host) _clientFactory;
  final Backoff _backoff;
  final Future<String?> Function()? _reResolveHost;
  final Duration _reResolveTimeout;
  final bool Function(Uint8List serverKeySha256)? _verifyServerKey;

  final StreamController<TvConnectionState> _states =
      StreamController<TvConnectionState>.broadcast();
  final StreamController<RemoteEvent> _events =
      StreamController<RemoteEvent>.broadcast();

  TvConnectionState _current = const TvConnectionState(
    status: ConnectionStatus.disconnected,
  );

  RemoteClient? _client;
  // Cancelled in _dropClient() and _detachClient().
  // ignore: cancel_subscriptions
  StreamSubscription<RemoteEvent>? _clientEvents;
  Timer? _timer;

  // Identifies the attempt (or cancellation) that callbacks belong to; a
  // callback whose token is stale does nothing.
  int _generation = 0;
  bool _disposed = false;
  Future<void>? _disposal;

  /// State changes, emitted only when [current] actually changes. A
  /// broadcast stream; read [current] for the state before subscribing.
  Stream<TvConnectionState> get states => _states.stream;

  /// The latest state.
  TvConnectionState get current => _current;

  /// The address the current or next attempt connects to: the constructor's
  /// `host` until a reconnect's `reResolveHost` returns a new one.
  String get host => _host;

  /// Everything the TV pushes (volume, power, current app, ...), forwarded
  /// from the current client across reconnects. `RemoteReady` and
  /// `RemoteClosed` are left out: [states] represents them. A broadcast
  /// stream.
  Stream<RemoteEvent> get events => _events.stream;

  /// Connects, completing once that first attempt has an outcome (see the
  /// class documentation; failures show in [states], they are not thrown).
  ///
  /// From `disconnected` (also after [disconnect]), `needsPairing` or
  /// `offline` this starts afresh. In
  /// `connecting` and `connected` it does nothing, and in `reconnecting` it
  /// behaves like [notifyAppResumed]. Throws a [StateError] after [dispose].
  Future<void> connect() async {
    if (_disposed) {
      throw StateError('This TvConnection was disposed.');
    }
    switch (_current.status) {
      case ConnectionStatus.connecting || ConnectionStatus.connected:
        return;
      case ConnectionStatus.reconnecting:
        return _retryNow();
      case ConnectionStatus.disconnected ||
          ConnectionStatus.needsPairing ||
          ConnectionStatus.offline:
        _cancelTimer();
        _backoff.reset();
        _set(const TvConnectionState(status: ConnectionStatus.connecting));
        return _runAttempt(reconnect: false);
    }
  }

  /// The app returned to the foreground: reconnect now if the connection is
  /// down (see the class documentation).
  void notifyAppResumed() => unawaited(_retryNow());

  /// The phone's network changed: reconnect now if the connection is down
  /// (see the class documentation).
  void notifyNetworkChanged() => unawaited(_retryNow());

  /// Presses [keyCode], see `RemoteClient.sendKey`.
  ///
  /// Throws [NotConnectedException] unless [ConnectionStatus.connected].
  void sendKey(int keyCode, {KeyDirection direction = KeyDirection.short}) =>
      _command((client) => client.sendKey(keyCode, direction: direction));

  /// Opens a deep link on the TV, see `RemoteClient.launchAppLink`.
  ///
  /// Throws [NotConnectedException] unless [ConnectionStatus.connected].
  void launchAppLink(String link) =>
      _command((client) => client.launchAppLink(link));

  /// Types [text] on the TV, see `RemoteClient.sendText`.
  ///
  /// Throws [NotConnectedException] unless [ConnectionStatus.connected].
  void sendText(String text) => _command((client) => client.sendText(text));

  /// Closes the connection cleanly and emits `disconnected`, but keeps this
  /// object usable: [connect] starts afresh afterwards.
  ///
  /// Cancels a scheduled retry, abandons an attempt in flight and closes the
  /// current client; completes once the client is closed. [notifyAppResumed]
  /// and [notifyNetworkChanged] do nothing while `disconnected`. Idempotent,
  /// and a no-op after [dispose].
  Future<void> disconnect() async {
    if (_disposed) return;
    _generation++;
    _cancelTimer();
    // The client is detached synchronously, so a connect() that follows
    // the emitted state cannot be disturbed by this close.
    final closing = _detachClient();
    _set(const TvConnectionState(status: ConnectionStatus.disconnected));
    await closing;
  }

  /// Stops reconnecting, closes the client, emits `disconnected` and closes
  /// [states] and [events]. Idempotent. [connect] throws afterwards.
  Future<void> dispose() => _disposal ??= _dispose();

  // ------------------------------------------------------------------ attempts

  /// Runs one connection attempt. Never throws.
  Future<void> _runAttempt({required bool reconnect}) async {
    final generation = ++_generation;
    if (reconnect) {
      final resolve = _reResolveHost;
      if (resolve != null) {
        try {
          final host = await resolve().timeout(_reResolveTimeout);
          if (host != null) _host = host;
        } on Object {
          // Keep the old host: the TV may simply be unreachable.
        }
        if (generation != _generation) return;
      }
    }
    await _detachClient();
    if (generation != _generation) return;

    final RemoteClient client;
    try {
      client = _clientFactory(_host);
    } on Object {
      _handleFailure(RemoteCloseReason.networkError);
      return;
    }
    _client = client;

    var ready = false;
    var trusted = false;
    RemoteCloseReason? closedWith;
    // TV pushes are held back until the TV's key was accepted.
    final early = <RemoteEvent>[];
    _clientEvents = client.events.listen((event) {
      if (generation != _generation) return;
      switch (event) {
        case RemoteReady():
          break;
        case RemoteClosed(:final reason):
          closedWith = reason;
          // Before ready the connect() exception reports the failure.
          if (ready) _handleLost(reason);
        case _:
          if (trusted) {
            _forward(event);
          } else {
            early.add(event);
          }
      }
    });

    try {
      await client.connect();
    } on RemoteConnectException catch (e) {
      if (generation == _generation) _handleFailure(e.reason);
      return;
    } on Object {
      if (generation == _generation) {
        _handleFailure(RemoteCloseReason.networkError);
      }
      return;
    }
    if (generation != _generation) return;

    ready = true;
    final lost = closedWith;
    if (lost != null) {
      // Closed again before this continuation ran.
      _handleLost(lost);
      return;
    }
    if (!client.isReady) return; // its RemoteClosed is on the way
    final accepted = _serverKeyAccepted(client);
    // The callback may have re-entered: dispose() or disconnect().
    if (generation != _generation) return;
    if (!accepted) {
      _handleFailure(RemoteCloseReason.serverKeyChanged);
      return;
    }
    trusted = true;
    _backoff.reset();
    _set(const TvConnectionState(status: ConnectionStatus.connected));
    early.forEach(_forward);
  }

  /// Whether [client]'s TV key passes `verifyServerKey` (always without one).
  bool _serverKeyAccepted(RemoteClient client) {
    final verify = _verifyServerKey;
    if (verify == null) return true;
    final key = client.serverPublicKeySha256;
    if (key == null) return false;
    try {
      return verify(Uint8List.fromList(key));
    } on Object {
      // Fail closed: an identity check that cannot decide does not pass.
      return false;
    }
  }

  void _forward(RemoteEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  /// A client that had been ready closed.
  void _handleLost(RemoteCloseReason reason) {
    _dropClient();
    _handleFailure(reason);
  }

  /// An attempt or a running session ended for [reason].
  void _handleFailure(RemoteCloseReason reason) {
    _dropClient();
    switch (reason) {
      case RemoteCloseReason.certificateRejected ||
          RemoteCloseReason.serverKeyChanged:
        _cancelTimer();
        _set(
          TvConnectionState(
            status: ConnectionStatus.needsPairing,
            attempt: _current.attempt,
            lastError: reason,
          ),
        );
      case RemoteCloseReason.closedByClient:
        _cancelTimer();
        _set(const TvConnectionState(status: ConnectionStatus.disconnected));
      case RemoteCloseReason.remoteClosed ||
          RemoteCloseReason.pingTimeout ||
          RemoteCloseReason.networkError:
        _scheduleReconnect(reason);
    }
  }

  void _scheduleReconnect(RemoteCloseReason reason) {
    final delay = _backoff.next();
    if (delay == null) {
      _set(
        TvConnectionState(
          status: ConnectionStatus.offline,
          attempt: _current.attempt,
          lastError: reason,
        ),
      );
      return;
    }
    _set(
      TvConnectionState(
        status: ConnectionStatus.reconnecting,
        attempt: _current.attempt + 1,
        lastError: reason,
      ),
    );
    _cancelTimer();
    _timer = Timer(delay, () {
      _timer = null;
      unawaited(_runAttempt(reconnect: true));
    });
  }

  /// Retries immediately from `reconnecting` or `offline`; does nothing
  /// otherwise.
  ///
  /// An attempt that is running (it may hang for the client's connect
  /// timeout, e.g. on a dead network) is abandoned: starting the new attempt
  /// bumps the generation, so the old one's outcome is ignored, and closes
  /// its client.
  Future<void> _retryNow() {
    if (_disposed) return Future<void>.value();
    switch (_current.status) {
      case ConnectionStatus.reconnecting || ConnectionStatus.offline:
        break;
      case ConnectionStatus.disconnected ||
          ConnectionStatus.connecting ||
          ConnectionStatus.connected ||
          ConnectionStatus.needsPairing:
        return Future<void>.value();
    }
    _cancelTimer();
    _backoff.reset();
    _set(
      TvConnectionState(
        status: ConnectionStatus.reconnecting,
        attempt: 1,
        lastError: _current.lastError,
      ),
    );
    return _runAttempt(reconnect: true);
  }

  // ------------------------------------------------------------------ helpers

  void _command(void Function(RemoteClient client) action) {
    final client = _client;
    if (_current.status != ConnectionStatus.connected ||
        client == null ||
        !client.isReady) {
      throw const NotConnectedException();
    }
    try {
      action(client);
      // RemoteClient reports "closed" as a StateError; that is the one case
      // this wrapper translates.
      // ignore: avoid_catching_errors
    } on StateError {
      // The client closed between the check and the call.
      throw const NotConnectedException();
    }
  }

  void _set(TvConnectionState next) {
    if (next == _current) return;
    _current = next;
    if (!_states.isClosed) _states.add(next);
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// Forgets the current client without waiting for it to close.
  void _dropClient() {
    final client = _client;
    final subscription = _clientEvents;
    _client = null;
    _clientEvents = null;
    unawaited(subscription?.cancel());
    if (client != null) unawaited(client.close());
  }

  Future<void> _detachClient() async {
    final client = _client;
    final subscription = _clientEvents;
    _client = null;
    _clientEvents = null;
    await subscription?.cancel();
    await client?.close();
  }

  Future<void> _dispose() async {
    _disposed = true;
    _generation++;
    _cancelTimer();
    await _detachClient();
    _set(const TvConnectionState(status: ConnectionStatus.disconnected));
    await _states.close();
    await _events.close();
  }
}
