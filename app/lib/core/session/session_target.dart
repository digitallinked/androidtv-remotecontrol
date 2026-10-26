import 'package:flutter/foundation.dart' show immutable;

/// Which TV the remote session should control.
///
/// A sealed class so a later phase can add other targets (e.g. the demo TV)
/// without touching the code that switches over it.
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
