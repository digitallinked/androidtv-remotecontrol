import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:tv_remote/core/session/remote_session.dart';

/// Something the demo TV was asked to do. The TV preview card shows the
/// latest one.
@immutable
sealed class DemoAction {
  /// Creates an action.
  const DemoAction();
}

/// A remote key was pressed, held or released.
final class DemoKeyPressed extends DemoAction {
  /// Creates the action.
  const DemoKeyPressed(this.keyCode, this.direction);

  /// The Android `KeyEvent` code of the key.
  final int keyCode;

  /// Whether it was a tap, the start of a hold or the end of one.
  final KeyDirection direction;

  @override
  bool operator ==(Object other) =>
      other is DemoKeyPressed &&
      other.keyCode == keyCode &&
      other.direction == direction;

  @override
  int get hashCode => Object.hash(DemoKeyPressed, keyCode, direction);

  @override
  String toString() => 'DemoKeyPressed($keyCode, $direction)';
}

/// A deep link (or `market://launch?id=<package>` link) was opened.
final class DemoAppOpened extends DemoAction {
  /// Creates the action.
  const DemoAppOpened(this.link);

  /// The link as it was sent.
  final String link;

  @override
  bool operator ==(Object other) =>
      other is DemoAppOpened && other.link == link;

  @override
  int get hashCode => Object.hash(DemoAppOpened, link);

  @override
  String toString() => 'DemoAppOpened($link)';
}

/// Text was typed into the TV.
final class DemoTextTyped extends DemoAction {
  /// Creates the action.
  const DemoTextTyped(this.text);

  /// The text that was sent.
  final String text;

  @override
  bool operator ==(Object other) =>
      other is DemoTextTyped && other.text == text;

  @override
  int get hashCode => Object.hash(DemoTextTyped, text);

  @override
  String toString() => 'DemoTextTyped';
}

/// A [RemoteSession] for a simulated TV: nothing is sent anywhere, no socket
/// is opened, and the TV never goes offline.
///
/// It behaves like a real session where the remote screen can tell: it
/// connects after a short delay, reports a volume and a power state, applies
/// volume, mute and power keys, and throws `NotConnectedException` from
/// commands until it is connected. Every command is also published as a
/// [DemoAction] for the TV preview card.
class DemoRemoteSession implements RemoteSession {
  /// Creates a disconnected demo TV. [connect] takes [connectDelay] to
  /// reach [ConnectionStatus.connected].
  DemoRemoteSession({this.connectDelay = const Duration(milliseconds: 600)});

  /// How long [connect] stays in [ConnectionStatus.connecting].
  final Duration connectDelay;

  /// The loudest level of the simulated TV.
  static const int _maxVolume = 20;

  /// The level the simulated TV starts at.
  static const int _startVolume = 8;

  TvConnectionState _current = const TvConnectionState(
    status: ConnectionStatus.disconnected,
  );
  final StreamController<TvConnectionState> _states =
      StreamController<TvConnectionState>.broadcast();
  final StreamController<RemoteEvent> _events =
      StreamController<RemoteEvent>.broadcast();
  final StreamController<DemoAction> _actions =
      StreamController<DemoAction>.broadcast();

  VolumeChanged? _volume;
  bool? _isPowerOn;
  String? _currentApp;
  DemoAction? _lastAction;

  Timer? _connectTimer;
  Completer<void>? _connecting;
  bool _disposed = false;

  @override
  String get tvName => '';

  @override
  bool get isDemo => true;

  @override
  DiscoveredTv? get pairingTarget => null;

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

  /// Everything the demo TV is asked to do, as a broadcast stream.
  Stream<DemoAction> get actions => _actions.stream;

  /// The latest action, or `null` before the first one.
  DemoAction? get lastAction => _lastAction;

  @override
  Future<void> connect() {
    if (_disposed || _current.status == ConnectionStatus.connected) {
      return Future.value();
    }
    final pending = _connecting;
    if (pending != null) return pending.future;

    final connecting = _connecting = Completer<void>();
    _setState(ConnectionStatus.connecting);
    _connectTimer = Timer(connectDelay, () {
      _connectTimer = null;
      _connecting = null;
      _setState(ConnectionStatus.connected);
      _isPowerOn = true;
      _emit(const PowerStateChanged(true));
      _publishVolume(const VolumeChanged(_startVolume, _maxVolume, false));
      connecting.complete();
    });
    return connecting.future;
  }

  @override
  Future<void> disconnect() async {
    if (_disposed) return;
    _cancelConnecting();
    _setState(ConnectionStatus.disconnected);
  }

  // The demo TV never goes offline: there is nothing to retry.
  @override
  void notifyAppResumed() {}

  @override
  void notifyNetworkChanged() {}

  @override
  void reconnect() {
    if (_current.status == ConnectionStatus.disconnected) {
      unawaited(connect());
    }
  }

  @override
  void sendKey(int keyCode, {KeyDirection direction = KeyDirection.short}) {
    _requireConnected();
    _record(DemoKeyPressed(keyCode, direction));
    // A release changes nothing: the press that started the hold already did.
    if (direction == KeyDirection.endLong) return;
    final volume = _volume!;
    switch (keyCode) {
      case KeyCodes.volumeUp:
        _publishVolume(_withLevel(volume, volume.level + 1));
      case KeyCodes.volumeDown:
        _publishVolume(_withLevel(volume, volume.level - 1));
      case KeyCodes.mute:
        _publishVolume(VolumeChanged(volume.level, volume.max, !volume.muted));
      case KeyCodes.power:
        final isOn = !(_isPowerOn ?? true);
        _isPowerOn = isOn;
        _emit(PowerStateChanged(isOn));
    }
  }

  @override
  void launchAppLink(String link) {
    _requireConnected();
    _record(DemoAppOpened(link));
    final uri = Uri.tryParse(link);
    final isMarketLaunch =
        uri != null && uri.scheme == 'market' && uri.host == 'launch';
    final package = isMarketLaunch ? uri.queryParameters['id'] : null;
    if (package != null && package.isNotEmpty) {
      _currentApp = package;
      _emit(CurrentAppChanged(package));
    }
  }

  @override
  void sendText(String text) {
    _requireConnected();
    _record(DemoTextTyped(text));
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _cancelConnecting();
    _setState(ConnectionStatus.disconnected);
    await _states.close();
    await _events.close();
    await _actions.close();
  }

  VolumeChanged _withLevel(VolumeChanged volume, int level) =>
      VolumeChanged(level.clamp(0, volume.max), volume.max, volume.muted);

  void _requireConnected() {
    if (_current.status != ConnectionStatus.connected) {
      throw const NotConnectedException();
    }
  }

  void _record(DemoAction action) {
    _lastAction = action;
    if (!_actions.isClosed) _actions.add(action);
  }

  void _setState(ConnectionStatus status) {
    _current = TvConnectionState(status: status);
    if (!_states.isClosed) _states.add(_current);
  }

  void _publishVolume(VolumeChanged volume) {
    _volume = volume;
    _emit(volume);
  }

  void _emit(RemoteEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  /// Stops a connect in progress; its caller's future completes.
  void _cancelConnecting() {
    _connectTimer?.cancel();
    _connectTimer = null;
    final pending = _connecting;
    _connecting = null;
    if (pending != null && !pending.isCompleted) pending.complete();
  }
}
