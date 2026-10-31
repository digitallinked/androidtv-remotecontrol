import 'dart:async';

import 'package:atv_remote/atv_remote.dart';

/// Creates a fresh [TvDiscovery]. A discovery can be watched only once, so
/// every browse starts from a new one.
typedef TvDiscoveryFactory = TvDiscovery Function();

/// Looks up the current address of a saved TV by its mDNS `serviceName`.
/// Returns `null` when the TV isn't found.
typedef HostResolver = Future<String?> Function(String serviceName);

/// Looks [serviceName] up with [resolve], counting a look-up that throws
/// (at once or later) or takes longer than [timeout] as "not found" (Ruling
/// P8-R10): the caller then falls back to the address it already has.
Future<String?> resolveHostOrNull(
  HostResolver resolve,
  String serviceName, {
  Duration timeout = const Duration(seconds: 4),
}) async {
  try {
    return await resolve(serviceName).timeout(timeout);
  } on Object {
    return null;
  }
}

/// Browses the network until a current-generation TV called [serviceName]
/// shows up and returns its host, or returns `null` after [timeout] or when
/// discovery fails.
///
/// Legacy `_androidtvremote._tcp` records are ignored: they can't be
/// controlled. The discovery is always stopped before this returns.
Future<String?> resolveHostByServiceName(
  TvDiscoveryFactory createDiscovery,
  String serviceName, {
  Duration timeout = const Duration(seconds: 4),
}) async {
  final discovery = createDiscovery();
  try {
    return await discovery
        .watch()
        .map<String?>((tvs) {
          for (final tv in tvs) {
            if (tv.serviceName == serviceName && !tv.isLegacyService) {
              return tv.host;
            }
          }
          return null;
        })
        .firstWhere((host) => host != null, orElse: () => null)
        .timeout(timeout, onTimeout: () => null);
  } on Object {
    // A discovery error means the host can't be resolved right now. The
    // caller falls back to the address it already has.
    return null;
  } finally {
    await discovery.stop();
  }
}
