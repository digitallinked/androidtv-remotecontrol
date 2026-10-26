import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:tv_remote/core/session/remote_client_factory.dart';
import 'package:tv_remote/core/session/remote_session.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/device_repository.dart';
import 'package:tv_remote/core/tv/host_resolver.dart';
import 'package:tv_remote/core/tv/manual_tv.dart';
import 'package:tv_remote/core/tv/saved_device_x.dart';
import 'package:tv_remote/core/tv/server_key_pin.dart';

/// A [RemoteSession] for a paired TV, wrapping a [TvConnection].
///
/// * The TV's key is checked against the pin stored at pairing (trust on
///   first use, decision #11). A device without a pin is
///   [ConnectionStatus.needsPairing] and no socket is ever opened to it.
/// * A key mismatch ([RemoteCloseReason.serverKeyChanged]) forgets the pin,
///   here and in storage, so nothing connects until the TV is paired again.
///   A rejected certificate keeps the pin; pairing again overwrites it.
/// * Every successful connection records the address used and the time in
///   storage. Storage failures are ignored: they never break the session.
/// * Reconnect attempts look the TV up again by its mDNS name, except for
///   TVs added by IP address.
class TvRemoteSession implements RemoteSession {
  /// Creates a session for [device], presenting [identity].
  ///
  /// [clientFactory] makes a new client for every attempt. [resolveHost]
  /// finds the TV's current address before reconnect attempts. [backoff]
  /// spaces the reconnect attempts (the `TvConnection` default when
  /// omitted); `now` stamps successful connections.
  TvRemoteSession({
    required SavedDevice device,
    required ClientIdentity identity,
    required this._devices,
    required RemoteClientFactory clientFactory,
    required HostResolver resolveHost,
    Backoff? backoff,
    this._now = DateTime.now,
  }) : _device = device,
       _pin = device.serverKeyPin {
    if (_pin == null) {
      _current = const TvConnectionState(status: ConnectionStatus.needsPairing);
      return;
    }
    final connection = _connection = TvConnection(
      host: device.lastHost,
      clientFactory: (h) =>
          clientFactory(host: h, port: device.port, identity: identity),
      backoff: backoff,
      reResolveHost: isManualServiceName(device.serviceName)
          ? null
          : () => resolveHost(device.serviceName),
      verifyServerKey: (sha) => matchesServerKeyPin(sha, _pin),
    );
    _current = connection.current;
    _connectionStates = connection.states.listen(_onState);
    _connectionEvents = connection.events.listen(_onEvent);
  }

  final SavedDevice _device;
  final DeviceRepository _devices;
  final DateTime Function() _now;

  // The trusted key; null once it no longer is (or never was).
  String? _pin;

  // Null when the device had no pin: no connection is ever made.
  TvConnection? _connection;
  StreamSubscription<TvConnectionState>? _connectionStates;
  StreamSubscription<RemoteEvent>? _connectionEvents;

  late TvConnectionState _current;
  final StreamController<TvConnectionState> _states =
      StreamController<TvConnectionState>.broadcast();
  final StreamController<RemoteEvent> _events =
      StreamController<RemoteEvent>.broadcast();

  VolumeChanged? _volume;
  bool? _isPowerOn;
  String? _currentApp;

  bool _disposed = false;
  Future<void>? _disposal;

  @override
  String get tvName => _device.label;

  @override
  bool get isDemo => false;

  @override
  DiscoveredTv? get pairingTarget => _device.toDiscoveredTv();

  // `current` follows the forwarded states (not `TvConnection.current`), so
  // a listener of `states` never sees the replayed state twice.
  @override
  TvConnectionState get current => _current;

  @override
  Stream<TvConnectionState> get states => Stream.multi((listener) {
    listener.add(_current);
    final subscription = _states.stream.listen(
      listener.add,
      onDone: listener.close,
    );
    listener.onCancel = subscription.cancel;
  });

  @override
  Stream<RemoteEvent> get events => _events.stream;

  @override
  VolumeChanged? get volume => _volume;

  @override
  bool? get isPowerOn => _isPowerOn;

  @override
  String? get currentApp => _currentApp;

  /// The connection, unless there is no trusted key to connect with (or the
  /// session was disposed).
  TvConnection? get _usableConnection {
    final connection = _connection;
    if (connection == null || _disposed) return null;
    final now = connection.current;
    if (now.status == ConnectionStatus.needsPairing &&
        now.lastError == RemoteCloseReason.serverKeyChanged) {
      // The state listener may not have run yet; the key is distrusted
      // from this moment.
      _pin = null;
    }
    return _pin == null ? null : connection;
  }

  @override
  Future<void> connect() async => _usableConnection?.connect();

  @override
  Future<void> disconnect() async {
    final connection = _connection;
    if (connection == null || _disposed) return;
    switch (connection.current.status) {
      case ConnectionStatus.needsPairing || ConnectionStatus.offline:
        // Nothing is open; disconnecting would only erase the message.
        return;
      case ConnectionStatus.disconnected ||
          ConnectionStatus.connecting ||
          ConnectionStatus.connected ||
          ConnectionStatus.reconnecting:
        await connection.disconnect();
    }
  }

  @override
  void notifyAppResumed() => _usableConnection?.notifyAppResumed();

  @override
  void notifyNetworkChanged() => _usableConnection?.notifyNetworkChanged();

  @override
  void reconnect() {
    final connection = _usableConnection;
    if (connection == null) return;
    if (connection.current.status == ConnectionStatus.disconnected) {
      unawaited(connection.connect());
    } else {
      connection.notifyNetworkChanged();
    }
  }

  @override
  void sendKey(int keyCode, {KeyDirection direction = KeyDirection.short}) =>
      _requireConnection().sendKey(keyCode, direction: direction);

  @override
  void launchAppLink(String link) => _requireConnection().launchAppLink(link);

  @override
  void sendText(String text) => _requireConnection().sendText(text);

  @override
  Future<void> dispose() => _disposal ??= _dispose();

  TvConnection _requireConnection() =>
      _connection ?? (throw const NotConnectedException());

  void _onState(TvConnectionState state) {
    _current = state;
    if (!_states.isClosed) _states.add(state);
    switch (state.status) {
      case ConnectionStatus.connected:
        final host = _connection!.host;
        _bestEffort(
          () => _devices.markConnected(
            _device.serviceName,
            host: host,
            at: _now().toUtc(),
          ),
        );
      case ConnectionStatus.needsPairing
          when state.lastError == RemoteCloseReason.serverKeyChanged:
        _pin = null;
        // Clear only the pin this session was built with: the user may have
        // paired again since, and that newer pin must survive.
        _bestEffort(
          () => _devices.clearServerKeyPin(
            _device.serviceName,
            distrustedPin: _device.serverKeyPin!,
          ),
        );
      case _:
        break;
    }
  }

  void _onEvent(RemoteEvent event) {
    switch (event) {
      case VolumeChanged():
        _volume = event;
      case PowerStateChanged(:final isOn):
        _isPowerOn = isOn;
      case CurrentAppChanged(:final package):
        _currentApp = package;
      case _:
        break;
    }
    if (!_events.isClosed) _events.add(event);
  }

  /// Runs a storage write, ignoring any failure (thrown or asynchronous).
  static void _bestEffort(Future<void> Function() write) => unawaited(
    Future.sync(write).then<void>((_) {}, onError: (Object _) {}),
  );

  Future<void> _dispose() async {
    _disposed = true;
    // The connection emits its final `disconnected` and closes its streams;
    // the listeners above see all of it before the controllers close.
    await _connection?.dispose();
    await _connectionStates?.cancel();
    await _connectionEvents?.cancel();
    await _states.close();
    await _events.close();
  }
}
