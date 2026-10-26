import 'package:atv_remote/atv_remote.dart';

/// Prefix of the `serviceName` of a TV added by IP address. These TVs are
/// never re-resolved through mDNS.
const manualServiceNamePrefix = 'manual:';

/// The Android TV Remote control port.
const _controlPort = 6466;

/// Returns the canonical dotted-quad form of [input] (after trimming), or
/// `null` when it isn't a usable unicast IPv4 address.
///
/// Each octet must be 0-255 without leading zeros. The first octet must be
/// 1-223 and not 127, which rules out "this network", loopback, multicast and
/// reserved addresses.
String? parseIpv4(String input) {
  final text = input.trim();
  final parts = text.split('.');
  if (parts.length != 4) return null;
  final octets = <int>[];
  for (final part in parts) {
    if (!RegExp(r'^(0|[1-9][0-9]{0,2})$').hasMatch(part)) return null;
    final value = int.parse(part);
    if (value > 255) return null;
    octets.add(value);
  }
  final first = octets.first;
  if (first < 1 || first > 223 || first == 127) return null;
  return text;
}

/// Whether [serviceName] belongs to a TV added by IP address.
bool isManualServiceName(String serviceName) =>
    serviceName.startsWith(manualServiceNamePrefix);

/// The TV record for an IPv4 address the user typed in. [ipv4] must come from
/// [parseIpv4].
DiscoveredTv manualTv(String ipv4) => DiscoveredTv(
  serviceName: '$manualServiceNamePrefix$ipv4',
  displayName: ipv4,
  host: ipv4,
  port: _controlPort,
  isLegacyService: false,
);
