import 'package:atv_remote/atv_remote.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/core/tv/manual_tv.dart';
import 'package:tv_remote/core/tv/saved_device_x.dart';
import 'package:tv_remote/features/discovery/data/discovery_providers.dart';

part 'pairing_providers.g.dart';

/// Creates the client that pairs with the TV at [host]. Tests override it
/// with a fake, so the UI never opens a socket.
typedef PairingClientFactory =
    PairingClient Function({
      required String host,
      required ClientIdentity identity,
    });

/// The factory of pairing clients.
@Riverpod(keepAlive: true)
PairingClientFactory pairingClientFactory(Ref ref) =>
    ({required host, required identity}) =>
        PairingClient(host: host, identity: identity);

/// The TV to pair when the route carries only its service name (the app was
/// restored, or the link was opened by hand).
///
/// It tries the saved TV, then an IP address typed in earlier
/// (`manual:<ip>`), then a look-up on the network. It is `null` when the TV
/// can't be found.
@Riverpod(retry: noRetry)
Future<DiscoveredTv?> pairingTarget(Ref ref, String serviceName) async {
  final devices = ref.watch(deviceRepositoryProvider);
  final resolveHost = ref.watch(hostResolverProvider);

  final saved = await devices.find(serviceName);
  if (saved != null) return saved.toDiscoveredTv();

  if (isManualServiceName(serviceName)) {
    final ip = parseIpv4(serviceName.substring(manualServiceNamePrefix.length));
    if (ip != null) return manualTv(ip);
  }

  final host = await resolveHost(serviceName);
  if (host == null) return null;
  return DiscoveredTv(
    serviceName: serviceName,
    displayName: serviceName.trim(),
    host: host,
    port: 6466,
    isLegacyService: false,
  );
}
