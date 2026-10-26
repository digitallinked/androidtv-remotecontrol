import 'package:flutter/foundation.dart' show immutable;

/// Which TV the remote session should control.
///
/// A sealed class so a new kind of target can be added without touching the
/// code that switches over it.
@immutable
sealed class SessionTarget {
  /// Creates a target.
  const SessionTarget();
}

/// A saved TV, identified by its `serviceName`.
final class DeviceTarget extends SessionTarget {
  /// Creates a target for the saved TV called [serviceName].
  const DeviceTarget(this.serviceName);

  /// The mDNS service name (or `manual:<ip>`) of the saved TV.
  final String serviceName;

  @override
  bool operator ==(Object other) =>
      other is DeviceTarget && other.serviceName == serviceName;

  @override
  int get hashCode => Object.hash(DeviceTarget, serviceName);

  @override
  String toString() => 'DeviceTarget';
}

/// The simulated demo TV. It needs no saved device and opens no socket.
final class DemoTarget extends SessionTarget {
  /// Creates the demo target.
  const DemoTarget();

  @override
  bool operator ==(Object other) => other is DemoTarget;

  @override
  int get hashCode => (DemoTarget).hashCode;

  @override
  String toString() => 'DemoTarget';
}
