@Tags(['integration'])
library;

import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/remote/application/remote_actions.dart';

import '../helpers/in_memory_device_repository.dart';
import '../helpers/paired_fake_tv.dart';
import '../helpers/pump_router_app.dart';
import '../helpers/real_remote_client.dart';
import '../helpers/wait_for.dart';

/// Ruling P8-R5: key-press-to-send stays under 30 ms at the 95th
/// percentile, measured from `RemoteActions.tap` to the fake TV reading the
/// key over loopback TLS. It measures the app's code path (actions, session,
/// connection, framing, TLS write), not Wi-Fi.
const Duration _budget = Duration(milliseconds: 30);
const int _warmUps = 5;
const int _measured = 50;

/// The median and the 95th percentile (nearest rank) of [samples].
///
/// The protocol library's latency test has a copy (the two packages share no
/// test code).
({Duration median, Duration p95}) latencyStats(List<Duration> samples) {
  if (samples.isEmpty) throw ArgumentError.value(samples, 'samples', 'empty');
  final sorted = [...samples]..sort();
  final n = sorted.length;
  final median = n.isOdd
      ? sorted[n ~/ 2]
      : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) ~/ 2;
  final p95 = sorted[(n * 0.95).ceil() - 1];
  return (median: median, p95: p95);
}

void main() {
  test('latency_stats_takes_the_median_and_the_nearest_rank_p95', () {
    final samples = [
      for (var ms = 20; ms >= 1; ms--) Duration(milliseconds: ms),
    ];
    final s = latencyStats(samples);
    expect(s.median, const Duration(microseconds: 10500));
    expect(s.p95, const Duration(milliseconds: 19));
    expect(
      latencyStats(const [Duration(milliseconds: 3)]),
      (
        median: const Duration(milliseconds: 3),
        p95: const Duration(milliseconds: 3),
      ),
    );
  });

  test(
    'key_press_to_send_under_30ms',
    () async {
      final (:tv, :device) = await startPairedFakeTv();

      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final store = await SettingsStore.open();
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: mergeOverrides(
          testAppOverrides(
            store: store,
            db: db,
            initialLocation: AppRoutes.remote,
          ),
          [
            deviceRepositoryProvider.overrideWithValue(
              InMemoryDeviceRepository([device]),
            ),
            // The app's real client, as production builds it.
            realRemoteClients(),
          ],
        ),
      );
      addTearDown(() async {
        container.dispose();
        // The session closes its client asynchronously.
        await waitFor(
          () => tv.openRemoteConnections == 0,
          reason: 'the app to close its connection to the TV',
        );
      });

      final actions = container.listen(remoteActionsProvider, (_, _) {});
      await waitFor(
        () =>
            container.read(remoteSessionProvider).value?.current.status ==
            ConnectionStatus.connected,
        reason: 'the session to connect to the fake TV',
      );
      await tv.waitForActiveClient();

      // The TV's key stream is synchronous: the listener stops the clock the
      // moment the TV has read the key.
      final watch = Stopwatch();
      Completer<Duration>? arrival;
      final keys = tv.keyCodes.listen((_) => arrival?.complete(watch.elapsed));
      addTearDown(keys.cancel);

      Future<Duration> press() async {
        final arrived = arrival = Completer<Duration>();
        watch
          ..reset()
          ..start();
        expect(actions.read().tap(KeyCodes.dpadUp), isTrue);
        return arrived.future.timeout(const Duration(seconds: 5));
      }

      for (var i = 0; i < _warmUps; i++) {
        await press();
      }
      final samples = [for (var i = 0; i < _measured; i++) await press()];
      await waitFor(
        () => tv.receivedKeyCodes.length == _warmUps + _measured,
        reason: 'the TV to record every press',
      );

      final s = latencyStats(samples);
      // The figures are for the report; they are host numbers, not device
      // numbers.
      // ignore: avoid_print
      print(
        'app key latency median=${s.median.inMicroseconds}us '
        'p95=${s.p95.inMicroseconds}us',
      );
      expect(s.p95, lessThan(_budget));
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );
}
