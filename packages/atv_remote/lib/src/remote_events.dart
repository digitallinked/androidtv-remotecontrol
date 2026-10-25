import 'package:meta/meta.dart';

/// Why a `RemoteClient` stopped.
enum RemoteCloseReason {
  /// The TV closed the connection after the session was running, or during
  /// the handshake after its first message.
  remoteClosed,

  /// No bytes arrived from the TV for the idle timeout while ready: the TV
  /// stopped pinging, so the connection is considered dead.
  pingTimeout,

  /// The TV does not accept this client's certificate: the TLS handshake
  /// failed, or the TV closed the connection before sending anything. The
  /// phone has to pair again.
  certificateRejected,

  /// Connecting failed or the connection broke: refused, unreachable, reset,
  /// timed out or corrupt data.
  networkError,

  /// `RemoteClient.close` was called.
  closedByClient,
}

/// Something that happened on the control channel.
///
/// Delivered on `RemoteClient.events`. [RemoteClosed] is always the last one.
@immutable
sealed class RemoteEvent {
  const RemoteEvent();
}

/// The handshake finished: controls may be enabled.
final class RemoteReady extends RemoteEvent {
  /// Creates the event.
  const RemoteReady();

  @override
  bool operator ==(Object other) => other is RemoteReady;

  @override
  int get hashCode => (RemoteReady).hashCode;

  @override
  String toString() => 'RemoteReady()';
}

/// The TV's screen turned on or off (`RemoteStart.started`).
final class PowerStateChanged extends RemoteEvent {
  /// Creates the event.
  // The positional bool is part of the specified API.
  // ignore: avoid_positional_boolean_parameters
  const PowerStateChanged(this.isOn);

  /// `true` when the screen is on.
  final bool isOn;

  @override
  bool operator ==(Object other) =>
      other is PowerStateChanged && other.isOn == isOn;

  @override
  int get hashCode => Object.hash(PowerStateChanged, isOn);

  @override
  String toString() => 'PowerStateChanged($isOn)';
}

/// The TV reported its volume.
final class VolumeChanged extends RemoteEvent {
  /// Creates the event.
  // The positional bool is part of the specified API.
  // ignore: avoid_positional_boolean_parameters
  const VolumeChanged(this.level, this.max, this.muted);

  /// Current volume.
  final int level;

  /// Highest possible volume.
  final int max;

  /// Whether the TV is muted.
  final bool muted;

  @override
  bool operator ==(Object other) =>
      other is VolumeChanged &&
      other.level == level &&
      other.max == max &&
      other.muted == muted;

  @override
  int get hashCode => Object.hash(VolumeChanged, level, max, muted);

  @override
  String toString() => 'VolumeChanged($level, $max, $muted)';
}

/// The TV reported the foreground app.
///
/// Emitted every time the TV names a non-empty package, even when it is the
/// same as before; the TV already sends it only when something changes.
final class CurrentAppChanged extends RemoteEvent {
  /// Creates the event.
  const CurrentAppChanged(this.package);

  /// Android package name of the foreground app.
  final String package;

  @override
  bool operator ==(Object other) =>
      other is CurrentAppChanged && other.package == package;

  @override
  int get hashCode => Object.hash(CurrentAppChanged, package);

  @override
  String toString() => 'CurrentAppChanged($package)';
}

/// A text field on the TV wants the keyboard.
final class ImeShowRequested extends RemoteEvent {
  /// Creates the event.
  const ImeShowRequested();

  @override
  bool operator ==(Object other) => other is ImeShowRequested;

  @override
  int get hashCode => (ImeShowRequested).hashCode;

  @override
  String toString() => 'ImeShowRequested()';
}

/// The TV sent a `RemoteError`.
final class RemoteErrorReceived extends RemoteEvent {
  /// Creates the event.
  const RemoteErrorReceived(this.message);

  /// A text rendering of the error for logs (not meant for end users).
  final String message;

  @override
  bool operator ==(Object other) =>
      other is RemoteErrorReceived && other.message == message;

  @override
  int get hashCode => Object.hash(RemoteErrorReceived, message);

  @override
  String toString() => 'RemoteErrorReceived($message)';
}

/// The connection ended. Always the last event; the stream closes after it.
final class RemoteClosed extends RemoteEvent {
  /// Creates the event.
  const RemoteClosed(this.reason);

  /// Why the connection ended.
  final RemoteCloseReason reason;

  @override
  bool operator ==(Object other) =>
      other is RemoteClosed && other.reason == reason;

  @override
  int get hashCode => Object.hash(RemoteClosed, reason);

  @override
  String toString() => 'RemoteClosed(${reason.name})';
}
