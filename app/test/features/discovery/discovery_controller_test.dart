import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsd/nsd.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/core/analytics/app_analytics.dart';
import 'package:tv_remote/core/session/remote_client_factory.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/session/session_signals.dart';
import 'package:tv_remote/core/session/session_target.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/discovery/application/discovery_controller.dart';
import 'package:tv_remote/features/discovery/data/discovery_providers.dart';

import '../../helpers/fake_remote_client.dart';
import '../../helpers/fake_tv_discovery.dart';
import '../../helpers/in_memory_device_repository.dart';
import '../../helpers/manual_session_signals.dart';
import '../../helpers/recording_analytics_sink.dart';
import '../../helpers/test_devices.dart';
import '../../helpers/test_identity.dart';

DiscoveredTv _named(String serviceName, String displayName) => DiscoveredTv(
  serviceName: serviceName,
  displayName: displayName,
  host: '192.168.0.20',
  port: 6466,
  isLegacyService: false,
);

/// A repository whose manual-to-mDNS merge waits until [release] completes.
class _SlowAdoptRepository extends InMemoryDeviceRepository {
  _SlowAdoptRepository(super.initial);

  final Completer<void> release = Completer<void>();

  @override
  Future<bool> adoptManualDevice({
    required String manualServiceName,
    required DiscoveredTv tv,
  }) async {
    await release.future;
    return super.adoptManualDevice(
      manualServiceName: manualServiceName,
      tv: tv,
    );
  }
}

void main() {
  late FakeTvDiscoveries discoveries;
  late RecordingAnalyticsSink analyticsSink;
  late SettingsStore settings;

  ProviderContainer makeContainer() {
    final container = ProviderContainer.test(
      overrides: [
        tvDiscoveryFactoryProvider.overrideWithValue(discoveries.create),
        settingsStoreProvider.overrideWithValue(settings),
        analyticsSinkProvider.overrideWithValue(analyticsSink),
        // The guard throws as in a debug build, so a bad event fails the test.
        analyticsDebugBuildProvider.overrideWithValue(true),
      ],
    )..listen(discoveryControllerProvider, (_, _) {}); // autoDispose
    return container;
  }

  DiscoveryState read(ProviderContainer c) =>
      c.read(discoveryControllerProvider);

  setUp(() async {
    discoveries = FakeTvDiscoveries();
    analyticsSink = RecordingAnalyticsSink();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    settings = await SettingsStore.open();
    await settings.setConsentRegion(ConsentRegion.notRequired);
  });

  test('state_compares_by_value', () {
    expect(
      DiscoveryState(
        tvs: [tv('a')],
        showTroubleshooting: false,
        failed: false,
      ),
      DiscoveryState(
        tvs: [tv('a')],
        showTroubleshooting: false,
        failed: false,
      ),
    );
    expect(
      DiscoveryState(
        tvs: [tv('a')],
        showTroubleshooting: false,
        failed: false,
      ),
      isNot(
        DiscoveryState(
          tvs: [tv('b')],
          showTroubleshooting: false,
          failed: false,
        ),
      ),
    );
  });

  test('sorts_tvs_by_display_name_case_insensitively', () {
    fakeAsync((async) {
      final c = makeContainer();
      discoveries.created.single.emit([tv('b'), tv('A'), tv('c')]);
      async.flushMicrotasks();
      expect(read(c).tvs.map((t) => t.displayName), ['A', 'b', 'c']);
    });
  });

  test('equal_names_are_ordered_by_service_name', () {
    fakeAsync((async) {
      final c = makeContainer();
      discoveries.created.single.emit([
        _named('z', 'Den'),
        _named('a', 'Den'),
      ]);
      async.flushMicrotasks();
      expect(read(c).tvs.map((t) => t.serviceName), ['a', 'z']);
    });
  });

  test('troubleshooting_after_10s_without_tvs', () {
    fakeAsync((async) {
      final c = makeContainer();
      async.elapse(const Duration(milliseconds: 9900));
      expect(read(c).showTroubleshooting, isFalse);
      async.elapse(const Duration(milliseconds: 100));
      expect(read(c).showTroubleshooting, isTrue);
      expect(read(c).failed, isFalse);
    });
  });

  test('no_troubleshooting_once_a_tv_is_found', () {
    fakeAsync((async) {
      final c = makeContainer();
      discoveries.created.single.emit([tv('a')]);
      async.elapse(discoveryEmptyTimeout * 2);
      expect(read(c).tvs, hasLength(1));
      expect(read(c).showTroubleshooting, isFalse);
    });
  });

  test('troubleshooting_returns_if_every_tv_disappears_after_10s', () {
    fakeAsync((async) {
      final c = makeContainer();
      discoveries.created.single.emit([tv('a')]);
      async.elapse(discoveryEmptyTimeout);
      discoveries.created.single.emit(const []);
      async.flushMicrotasks();
      expect(read(c).showTroubleshooting, isTrue);
    });
  });

  test('start_failure_sets_failed_and_troubleshooting', () {
    fakeAsync((async) {
      final c = makeContainer();
      discoveries.created.single.fail(
        NsdError(ErrorCause.securityIssue, 'denied'),
      );
      async.flushMicrotasks();
      expect(read(c).failed, isTrue);
      expect(read(c).showTroubleshooting, isTrue);
    });
  });

  test('rescan_restarts_discovery_and_the_timer', () {
    fakeAsync((async) {
      final c = makeContainer();
      async.elapse(discoveryEmptyTimeout);
      expect(read(c).showTroubleshooting, isTrue);

      c.read(discoveryControllerProvider.notifier).rescan();
      async.elapse(Duration.zero);

      expect(discoveries.created, hasLength(2));
      expect(discoveries.created.first.stopped, isTrue);
      expect(discoveries.created.last.stopped, isFalse);
      expect(read(c).showTroubleshooting, isFalse);
      async.elapse(const Duration(milliseconds: 9900));
      expect(read(c).showTroubleshooting, isFalse);
      async.elapse(const Duration(milliseconds: 100));
      expect(read(c).showTroubleshooting, isTrue);
    });
  });

  test('rescan_clears_a_failure', () {
    fakeAsync((async) {
      final c = makeContainer();
      discoveries.created.single.fail(StateError('x'));
      async.flushMicrotasks();
      expect(read(c).failed, isTrue);

      c.read(discoveryControllerProvider.notifier).rescan();
      async.elapse(Duration.zero);
      expect(read(c).failed, isFalse);
      expect(read(c).tvs, isEmpty);
    });
  });

  test('dispose_stops_discovery', () {
    fakeAsync((async) {
      final c = makeContainer();
      final first = discoveries.created.single;
      expect(first.stopped, isFalse);
      c.dispose();
      async.flushMicrotasks();
      expect(first.stopped, isTrue);
      // The timer was cancelled: nothing is left to fire.
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('tv_discovered_logged_once_with_a_count', () {
    fakeAsync((async) {
      final c = makeContainer();
      async.flushMicrotasks();
      expect(analyticsSink.calls, isEmpty);

      discoveries.created.single.emit([tv('a'), tv('b')]);
      async.flushMicrotasks();
      expect(analyticsSink.eventNames, ['tv_discovered']);
      expect(analyticsSink.events.single.params, {'count': 2});

      // More TVs, fewer TVs, none and a rescan do not log it again.
      discoveries.created.single.emit([tv('a'), tv('b'), tv('c')]);
      async.flushMicrotasks();
      discoveries.created.single.emit(const []);
      async.flushMicrotasks();
      c.read(discoveryControllerProvider.notifier).rescan();
      async.elapse(Duration.zero);
      discoveries.created.last.emit([tv('a')]);
      async.flushMicrotasks();
      expect(analyticsSink.eventNames, ['tv_discovered']);
    });
  });

  group('merge follow-up', () {
    const manual = 'manual:192.168.0.20';
    late FakeRemoteClients clients;

    /// A container with real sessions over [repo]. The session is listened
    /// to (as the remote keeps it alive); discovery isn't.
    ProviderContainer sessionContainer(InMemoryDeviceRepository repo) {
      clients = FakeRemoteClients();
      return ProviderContainer.test(
        overrides: [
          tvDiscoveryFactoryProvider.overrideWithValue(discoveries.create),
          settingsStoreProvider.overrideWithValue(settings),
          analyticsSinkProvider.overrideWithValue(analyticsSink),
          deviceRepositoryProvider.overrideWithValue(repo),
          identityStoreProvider.overrideWithValue(testIdentityStore()),
          remoteClientFactoryProvider.overrideWithValue(clients.create),
          hostResolverProvider.overrideWithValue((_) async => null),
          sessionSignalsProvider.overrideWithValue(ManualSessionSignals()),
        ],
      )..listen(remoteSessionProvider, (_, _) {});
    }

    test('merge_after_leaving_discovery_moves_the_default_session', () async {
      final repo = _SlowAdoptRepository([
        savedTv(name: manual, nickname: 'Den'),
      ]);
      final c = sessionContainer(repo);
      // No explicit target: the default session follows the manual row.
      final old = (await c.read(remoteSessionProvider.future))!;
      expect(old.pairingTarget!.serviceName, manual);

      final discovery = c.listen(discoveryControllerProvider, (_, _) {});
      final merging = c
          .read(discoveryControllerProvider.notifier)
          .adoptManualDevice(
            manualServiceName: manual,
            tv: tv('Living Room TV 3'),
            opening: () => false,
          );
      // The user leaves discovery while the merge is still running.
      discovery.close();
      await pumpEventQueue();
      expect(c.exists(discoveryControllerProvider), isFalse);

      repo.release.complete();
      expect(await merging, isTrue);

      expect(repo.saved.keys, ['Living Room TV 3']);
      // Nobody is pulled onto a target: the default session moves instead.
      expect(c.read(activeTargetProvider), isNull);
      final session = await c.read(remoteSessionProvider.future);
      expect(session, isNot(same(old)));
      expect(session!.pairingTarget!.serviceName, 'Living Room TV 3');
      expect(clients.created.first.closed, isTrue);
    });

    test('merge_leaves_a_session_on_another_tv_alone', () async {
      final repo = InMemoryDeviceRepository([
        savedTv(name: manual, at: DateTime.utc(2026, 10, 25, 9)),
        savedTv(name: 'Bedroom TV', at: DateTime.utc(2026, 10, 25, 12)),
      ]);
      final c = sessionContainer(repo);
      final old = (await c.read(remoteSessionProvider.future))!;
      expect(old.pairingTarget!.serviceName, 'Bedroom TV');

      final discovery = c.listen(discoveryControllerProvider, (_, _) {});
      final merged = await c
          .read(discoveryControllerProvider.notifier)
          .adoptManualDevice(
            manualServiceName: manual,
            tv: tv('Living Room TV 3'),
            opening: () => false,
          );
      discovery.close();

      expect(merged, isTrue);
      expect(c.read(activeTargetProvider), isNull);
      expect(await c.read(remoteSessionProvider.future), same(old));
    });

    test('merge_while_opening_activates_the_merged_tv', () async {
      final repo = InMemoryDeviceRepository([
        savedTv(name: manual, at: DateTime.utc(2026, 10, 25, 9)),
        savedTv(name: 'Bedroom TV', at: DateTime.utc(2026, 10, 25, 12)),
      ]);
      final c = sessionContainer(repo)
        ..listen(discoveryControllerProvider, (_, _) {});
      final merged = await c
          .read(discoveryControllerProvider.notifier)
          .adoptManualDevice(
            manualServiceName: manual,
            tv: tv('Living Room TV 3'),
            opening: () => true,
          );

      expect(merged, isTrue);
      expect(
        c.read(activeTargetProvider),
        const DeviceTarget('Living Room TV 3'),
      );
      final session = await c.read(remoteSessionProvider.future);
      expect(session!.pairingTarget!.serviceName, 'Living Room TV 3');
    });
  });
}
