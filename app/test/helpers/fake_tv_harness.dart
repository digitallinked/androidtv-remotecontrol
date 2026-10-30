import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:atv_remote/testing.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/flavor.dart';
import 'package:tv_remote/core/session/remote_client_factory.dart';
import 'package:tv_remote/features/discovery/data/discovery_providers.dart';
import 'package:tv_remote/features/pairing/data/pairing_providers.dart';

import 'fake_tv_discovery.dart';
import 'test_identity.dart';

/// The protocol library's fake TV, wired into the app the way a real TV is:
/// discovery finds it, and the app's real pairing and remote clients talk to
/// it over loopback TLS.
///
/// Only discovery is faked (mDNS can't be faked over loopback); pairing and
/// the remote connection are the production code paths. Drive the app with
/// `pumpUntil`, which lets the real sockets make progress.
class FakeTvHarness {
  FakeTvHarness._(this._tester, this.tv) {
    // The controller listens right after creating a discovery; the microtask
    // runs once it has.
    discoveries.onCreate = (discovery) =>
        scheduleMicrotask(() => discovery.emit([discovered]));
  }

  /// Starts a fake TV and lets [testIdentity] through its TLS handshake.
  ///
  /// The server runs in real time (inside `runAsync`), so its timers and
  /// sockets work while the test's clock is fake.
  static Future<FakeTvHarness> start(WidgetTester t) async {
    final tv = await t.runAsync(() {
      FakeTvServer.trustClient(testIdentity());
      // A ping a second keeps the keep-alive exercised without making a slow
      // machine, which runs the app's side of the socket only between
      // frames, miss three pings in a row.
      return FakeTvServer.start(pingInterval: const Duration(seconds: 1));
    });
    return FakeTvHarness._(t, tv!);
  }

  final WidgetTester _tester;

  /// The fake TV.
  final FakeTvServer tv;

  /// The discoveries the app created; each one finds [discovered].
  final FakeTvDiscoveries discoveries = FakeTvDiscoveries();

  /// The fake TV as discovery reports it.
  DiscoveredTv get discovered => DiscoveredTv(
    serviceName: 'Fake TV',
    displayName: 'Fake TV',
    host: '127.0.0.1',
    port: tv.remotePort,
    isLegacyService: false,
  );

  /// Overrides that point the app at [tv]: discovery finds it, pairing goes
  /// to its pairing port, and remote clients are the real ones.
  List<Override> get overrides => [
    tvDiscoveryFactoryProvider.overrideWithValue(discoveries.create),
    pairingClientFactoryProvider.overrideWithValue(
      ({required host, required identity}) =>
          PairingClient(host: host, port: tv.pairingPort, identity: identity),
    ),
    remoteClientFactoryProvider.overrideWithValue(
      ({required host, required port, required identity}) => RemoteClient(
        host: host,
        port: port,
        identity: identity,
        deviceInfo: deviceInfoFor(Flavor.dev),
      ),
    ),
  ];

  /// Stops the fake TV and drops its connections.
  Future<void> close() => _tester.runAsync(tv.close);
}
