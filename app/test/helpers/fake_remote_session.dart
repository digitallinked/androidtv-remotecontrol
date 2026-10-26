import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:tv_remote/core/session/remote_session.dart';

/// A [RemoteSession] that tests drive by hand: [emit] sets the state, [push]
/// delivers a TV event, and every call is recorded.
class FakeRemoteSession implements RemoteSession {
  /// Creates a session in state [initial].
  FakeRemoteSession({
    this.tvName = 'Living Room TV 3',
    this.isDemo = false,
    this.pairingTarget,
    TvConnectionState initial = const TvConnectionState(
      status: ConnectionStatus.disconnected,
    ),
  }) : _current = initial;

  @override
  final String tvName;

  @override
  final bool isDemo;

  @override
  final DiscoveredTv? pairingTarget;

  TvConnectionState _current;
  final StreamController<TvConnectionState> _states =
      StreamController<TvConnectionState>.broadcast();
  final StreamController<RemoteEvent> _events =
      StreamController<RemoteEvent>.broadcast();

  VolumeChanged? _volume;
  bool? _isPowerOn;
  String? _currentApp;

  /// Key codes sent while connected, in order.
  final List<int> sentKeys = [];

  /// Deep links sent while connected, in order.
  final List<String> sentLinks = [];

  /// Texts sent while connected, in order.
  final List<String> sentTexts = [];

  /// How often [connect] was called.
  int connectCalls = 0;

  /// How often [disconnect] was called.
  int disconnectCalls = 0;

  /// How often [notifyAppResumed] was called.
  int resumeCalls = 0;

  /// How often [notifyNetworkChanged] was called.
  int networkCalls = 0;

  /// How often [reconnect] was called.
  int reconnectCalls = 0;

  /// Whether [dispose] was called.
  bool disposed = false;

  /// Makes [state] the current state and emits it on [states].
  void emit(TvConnectionState state) {
    _current = state;
    if (!_states.isClosed) _states.add(state);
  }

  /// Delivers [event] as if the TV pushed it, updating [volume], [isPowerOn]
  /// and [currentApp] first.
  void push(RemoteEvent event) {
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

  @override
  Future<void> connect() async => connectCalls++;

  @override
  Future<void> disconnect() async => disconnectCalls++;

  @override
  void notifyAppResumed() => resumeCalls++;

  @override
  void notifyNetworkChanged() => networkCalls++;

  @override
  void reconnect() => reconnectCalls++;

  @override
  void sendKey(int keyCode, {KeyDirection direction = KeyDirection.short}) {
    _requireConnected();
    sentKeys.add(keyCode);
  }

  @override
  void launchAppLink(String link) {
    _requireConnected();
    sentLinks.add(link);
  }

  @override
  void sendText(String text) {
    _requireConnected();
    sentTexts.add(text);
  }

  @override
  Future<void> dispose() async {
    if (disposed) return;
    disposed = true;
    await _states.close();
    await _events.close();
  }

  void _requireConnected() {
    if (_current.status != ConnectionStatus.connected) {
      throw const NotConnectedException();
    }
  }
}
