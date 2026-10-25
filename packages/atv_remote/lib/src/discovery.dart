import 'package:meta/meta.dart';

/// mDNS service type of the current Android TV Remote Service.
const String _serviceTypeV2 = '_androidtvremote2._tcp';

/// mDNS service type of the legacy (v1) service. The TV needs its "Android TV
/// Remote Service" updated before it can be controlled.
const String _serviceTypeLegacy = '_androidtvremote._tcp';

/// A TV found on the local network.
@immutable
class DiscoveredTv {
  /// Creates a record.
  const DiscoveredTv({
    required this.serviceName,
    required this.displayName,
    required this.host,
    required this.port,
    required this.isLegacyService,
  });

  /// The raw mDNS instance name.
  final String serviceName;

  /// The instance name trimmed, for showing to the user.
  final String displayName;

  /// IP address or host name to connect to.
  final String host;

  /// Port of the advertised service (the control port, 6466).
  final int port;

  /// Whether the TV advertised the legacy `_androidtvremote._tcp` service
  /// instead of `_androidtvremote2._tcp`.
  final bool isLegacyService;

  @override
  bool operator ==(Object other) =>
      other is DiscoveredTv &&
      other.serviceName == serviceName &&
      other.displayName == displayName &&
      other.host == host &&
      other.port == port &&
      other.isLegacyService == isLegacyService;

  @override
  int get hashCode =>
      Object.hash(serviceName, displayName, host, port, isLegacyService);

  @override
  String toString() =>
      'DiscoveredTv($displayName, $host:$port'
      '${isLegacyService ? ', legacy' : ''})';
}

/// Finds TVs on the network. Implemented by the app (Phase 3) on top of a
/// platform mDNS plugin; this package holds no mDNS code.
abstract interface class TvDiscovery {
  /// Emits the current list of known TVs, again whenever it changes.
  Stream<List<DiscoveredTv>> watch();

  /// Stops browsing and releases platform resources.
  Future<void> stop();
}

/// Turns the fields of a resolved mDNS service into a [DiscoveredTv].
///
/// [serviceType] may be written with or without a trailing dot or a `.local`
/// suffix. Throws an [ArgumentError] for any type other than
/// `_androidtvremote2._tcp` and `_androidtvremote._tcp` (legacy).
DiscoveredTv parseServiceRecord({
  required String serviceType,
  required String name,
  required String host,
  required int port,
}) {
  var type = serviceType.toLowerCase();
  if (type.endsWith('.')) type = type.substring(0, type.length - 1);
  if (type.endsWith('.local')) type = type.substring(0, type.length - 6);
  final bool legacy;
  switch (type) {
    case _serviceTypeV2:
      legacy = false;
    case _serviceTypeLegacy:
      legacy = true;
    default:
      throw ArgumentError.value(
        serviceType,
        'serviceType',
        'not an Android TV Remote service',
      );
  }
  return DiscoveredTv(
    serviceName: name,
    displayName: name.trim(),
    host: host,
    port: port,
    isLegacyService: legacy,
  );
}
