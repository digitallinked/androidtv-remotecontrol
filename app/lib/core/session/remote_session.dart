import 'package:atv_remote/atv_remote.dart';

/// The remote screen's view of one TV: connection state, what the TV
/// reports, and the commands it accepts.
///
/// The UI talks to this, never to `TvConnection` (Ruling 1). A real TV is a
/// `TvRemoteSession`; the demo TV implements the same interface. Widgets may
/// read [isDemo] only to show the demo badge, the TV preview and the "Demo
/// TV" name, never to change behaviour.
abstract interface class RemoteSession {
  /// The name shown for the TV (its nickname, or the name it announced).
  /// Empty for the demo TV, whose name the UI shows localised instead.
  String get tvName;

  /// Whether this is the simulated demo TV. Only for the demo badge, the TV
  /// preview and the TV name.
  bool get isDemo;

  /// Where "Pair again" leads: this TV as a discovery record at its last
  /// known address. `null` for the demo TV, which never needs pairing.
  DiscoveredTv? get pairingTarget;

  /// The connection state to show now. Enable the controls only while it is
  /// [ConnectionStatus.connected].
  TvConnectionState get current;

  /// The connection state for the status pill: emits [current] to every new
  /// listener, then each change.
  Stream<TvConnectionState> get states;

  /// What the TV pushes (volume, power, foreground app, keyboard requests,
  /// errors), as a broadcast stream. Connection changes are on [states].
  Stream<RemoteEvent> get events;

  /// The volume the TV last reported, or `null` before it reported one.
  VolumeChanged? get volume;

  /// Whether the TV last reported its screen on, or `null` before it
  /// reported.
  bool? get isPowerOn;

  /// The package of the app the TV last reported in the foreground, or
  /// `null` before it reported one.
  String? get currentApp;

  /// Starts connecting; completes once the first attempt has an outcome.
  /// Failures show in [states], they are not thrown. Does nothing while the
  /// TV needs pairing because no trusted key is stored.
  Future<void> connect();

  /// Closes the connection, ending in [ConnectionStatus.disconnected] (used
  /// after a while in the background); [connect] starts again. Keeps
  /// [ConnectionStatus.needsPairing] and [ConnectionStatus.offline], where
  /// nothing is open, so the UI keeps their message.
  Future<void> disconnect();

  /// The app came back to the foreground: retry now if the connection is
  /// reconnecting or offline.
  void notifyAppResumed();

  /// The phone's network changed: retry now if the connection is
  /// reconnecting or offline, looking the TV's address up again.
  void notifyNetworkChanged();

  /// The user tapped "Reconnect": connects from
  /// [ConnectionStatus.disconnected], otherwise retries like
  /// [notifyNetworkChanged] (Ruling 10).
  void reconnect();

  /// Presses [keyCode] (see `KeyCodes`) on the TV; a tap unless [direction]
  /// says press-and-hold.
  ///
  /// Throws `NotConnectedException` unless the connection is up. [current]
  /// can lag the socket, so enabled controls don't guarantee success: always
  /// catch `NotConnectedException`.
  void sendKey(int keyCode, {KeyDirection direction = KeyDirection.short});

  /// Opens a deep link (or `market://launch?id=<package>`) on the TV.
  ///
  /// Throws `NotConnectedException` unless the connection is up. [current]
  /// can lag the socket, so enabled controls don't guarantee success: always
  /// catch `NotConnectedException`.
  void launchAppLink(String link);

  /// Types [text] into the TV's focused text field.
  ///
  /// Throws `NotConnectedException` unless the connection is up. [current]
  /// can lag the socket, so enabled controls don't guarantee success: always
  /// catch `NotConnectedException`.
  void sendText(String text);

  /// Closes the connection and the streams for good, when the remote screen
  /// no longer needs this TV. Idempotent.
  Future<void> dispose();
}
