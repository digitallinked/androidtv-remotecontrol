import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/flavor.dart';
import 'package:tv_remote/core/session/remote_client_factory.dart';
import 'package:tv_remote/core/session/remote_session.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/session/session_signals.dart';
import 'package:tv_remote/core/session/session_target.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/device_repository.dart';
import 'package:tv_remote/core/storage/identity_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/discovery/data/discovery_providers.dart';

import '../../helpers/fake_remote_client.dart';
import '../../helpers/in_memory_secure_store.dart';
import '../../helpers/manual_session_signals.dart';
import '../../helpers/test_devices.dart';
import '../../helpers/test_identity.dart';

/// Waits until [session] reports `connected`.
Future<void> untilConnected(RemoteSession session) => session.states
    .firstWhere((s) => s.status == ConnectionStatus.connected)
    .timeout(const Duration(seconds: 5));

void main() {
  late AppDatabase db;
  late DriftDeviceRepository repo;
  late FakeRemoteClients clients;
  late ManualSessionSignals signals;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftDeviceRepository(db);
    clients = FakeRemoteClients();
    signals = ManualSessionSignals();
  });
  tearDown(() => db.close());

  List<Override> overrides({
    IdentityStore? identityStore,
    SessionTiming timing = const SessionTiming(),
  }) => [
    appDatabaseProvider.overrideWithValue(db),
    identityStoreProvider.overrideWithValue(
      identityStore ?? testIdentityStore(),
    ),
    remoteClientFactoryProvider.overrideWithValue(clients.create),
    hostResolverProvider.overrideWithValue((_) async => null),
    flavorProvider.overrideWithValue(Flavor.dev),
    sessionSignalsProvider.overrideWithValue(signals),
    sessionTimingProvider.overrideWithValue(timing),
  ];

  ProviderContainer makeContainer({
    IdentityStore? identityStore,
    SessionTiming timing = const SessionTiming(),
  }) => ProviderContainer.test(
    overrides: overrides(identityStore: identityStore, timing: timing),
  );

  Future<void> saveTwo() async {
    await repo.upsert(
      savedTv(name: 'a', at: DateTime.utc(2026, 10, 25, 12, 1)),
    );
    await repo.upsert(
      savedTv(
        name: 'b',
        host: '192.168.0.21',
        at: DateTime.utc(2026, 10, 25, 12, 3),
      ),
    );
  }

  test('session_target_compares_by_value', () {
    expect(const DeviceTarget('a'), const DeviceTarget('a'));
    expect(const DeviceTarget('a').hashCode, const DeviceTarget('a').hashCode);
    expect(const DeviceTarget('a'), isNot(const DeviceTarget('b')));
  });

  test('session_follows_the_last_used_device_by_default', () async {
    await saveTwo();
    final c = makeContainer()..listen(remoteSessionProvider, (_, _) {});
    expect((await c.read(remoteSessionProvider.future))!.tvName, 'b');
  });

  test('clearing_the_target_goes_back_to_the_last_used_device', () async {
    await saveTwo();
    final c = makeContainer()..listen(remoteSessionProvider, (_, _) {});
    c.read(activeTargetProvider.notifier).activateDevice('a');
    expect((await c.read(remoteSessionProvider.future))!.tvName, 'a');
    c.read(activeTargetProvider.notifier).clear();
    expect(c.read(activeTargetProvider), isNull);
    expect((await c.read(remoteSessionProvider.future))!.tvName, 'b');
  });

  test('no_saved_device_gives_no_session_and_disconnected_state', () async {
    final c = makeContainer()..listen(connectionStateProvider, (_, _) {});
    expect(await c.read(remoteSessionProvider.future), isNull);
    final state = await c.read(connectionStateProvider.future);
    expect(state.status, ConnectionStatus.disconnected);
    expect(clients.created, isEmpty);
  });

  test('session_connects_when_created', () async {
    await repo.upsert(savedTv(name: 'a'));
    final c = makeContainer();
    final states = <ConnectionStatus>[];
    c.listen(
      connectionStateProvider,
      (_, next) => next.whenData((s) => states.add(s.status)),
    );
    final session = (await c.read(remoteSessionProvider.future))!;
    await untilConnected(session);
    await pumpEventQueue();
    expect(states, contains(ConnectionStatus.connected));
    expect(
      (await c.read(connectionStateProvider.future)).status,
      ConnectionStatus.connected,
    );
    expect(clients.created, hasLength(1));
    expect(clients.created.single.host, '192.168.0.20');
  });

  test(
    'activate_device_switches_the_session_and_disposes_the_old_one',
    () async {
      await repo.upsert(savedTv(name: 'a'));
      await repo.upsert(savedTv(name: 'b', host: '192.168.0.21'));
      final c = makeContainer()..listen(remoteSessionProvider, (_, _) {});
      final first = (await c.read(remoteSessionProvider.future))!;
      await untilConnected(first);
      c.read(activeTargetProvider.notifier).activateDevice('a');
      final second = (await c.read(remoteSessionProvider.future))!;
      expect(second.tvName, 'a');
      expect(identical(first, second), isFalse);
      await untilConnected(second);
      await pumpEventQueue();
      // Exactly one live client.
      expect(clients.created.first.closed, isTrue);
      expect(clients.created.where((x) => !x.closed), hasLength(1));
    },
  );

  test('activating_the_same_device_again_rebuilds_the_session', () async {
    await repo.upsert(savedTv(name: 'a'));
    final c = makeContainer()..listen(remoteSessionProvider, (_, _) {});
    c.read(activeTargetProvider.notifier).activateDevice('a');
    final first = (await c.read(remoteSessionProvider.future))!;
    c.read(activeTargetProvider.notifier).activateDevice('a');
    final second = (await c.read(remoteSessionProvider.future))!;
    expect(identical(first, second), isFalse);
    expect(second.tvName, 'a');
  });

  test('re_pairing_gives_a_new_session_that_can_connect', () async {
    // The TV was saved without a trusted key: its session never connects.
    await repo.upsert(savedTv(name: 'a', noPin: true));
    final c = makeContainer()..listen(remoteSessionProvider, (_, _) {});
    final inert = (await c.read(remoteSessionProvider.future))!;
    expect(inert.current.status, ConnectionStatus.needsPairing);
    await pumpEventQueue();
    expect(clients.created, isEmpty);

    // Pairing stores the new pin, then activates the TV.
    await repo.upsert(savedTv(name: 'a'));
    c.read(activeTargetProvider.notifier).activateDevice('a');
    final fresh = (await c.read(remoteSessionProvider.future))!;
    expect(identical(inert, fresh), isFalse);
    await untilConnected(fresh);
    expect(clients.created, hasLength(1));
    expect(inert.current.status, ConnectionStatus.needsPairing);
  });

  test('identity_failure_surfaces_as_error_without_retry', () async {
    await repo.upsert(savedTv(name: 'a'));
    var generated = 0;
    final store = IdentityStore(
      InMemorySecureKeyValueStore()
        ..throwOnWrite = PlatformException(code: 'x'),
      generate: () async {
        generated++;
        return testIdentity();
      },
    );
    final c = makeContainer(identityStore: store)
      ..listen(remoteSessionProvider, (_, _) {});
    await expectLater(
      c.read(remoteSessionProvider.future),
      throwsA(isA<IdentityStoreException>()),
    );
    // Riverpod's default first retry would come after 200 ms.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(generated, 1);
    expect(clients.created, isEmpty);
  });

  test(
    'switching_while_the_identity_loads_never_builds_the_old_session',
    () async {
      await saveTwo();
      final gate = Completer<void>();
      final store = IdentityStore(
        InMemorySecureKeyValueStore(),
        generate: () async {
          await gate.future;
          return testIdentity();
        },
      );
      final c = makeContainer(identityStore: store)
        ..listen(remoteSessionProvider, (_, _) {});
      final stale = c.read(remoteSessionProvider.future);
      await pumpEventQueue();
      c.read(activeTargetProvider.notifier).activateDevice('a');
      gate.complete();
      final session = (await c.read(remoteSessionProvider.future))!;
      await untilConnected(session);
      await stale;
      await pumpEventQueue();
      expect(session.tvName, 'a');
      expect(clients.created.map((x) => x.host), ['192.168.0.20']);
    },
  );

  test(
    'session_backed_providers_surface_the_identity_error_and_keep_it',
    () async {
      await repo.upsert(savedTv(name: 'a'));
      final store = IdentityStore(
        InMemorySecureKeyValueStore()
          ..throwOnWrite = PlatformException(code: 'x'),
        generate: () async => testIdentity(),
      );
      final c = makeContainer(identityStore: store)
        ..listen(remoteSessionProvider, (_, _) {})
        ..listen(connectionStateProvider, (_, _) {})
        ..listen(volumeProvider, (_, _) {})
        ..listen(powerStateProvider, (_, _) {})
        ..listen(currentAppProvider, (_, _) {});
      // Riverpod's default retry would re-run them from 200 ms on.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      for (final state in [
        c.read(connectionStateProvider),
        c.read(volumeProvider),
        c.read(powerStateProvider),
        c.read(currentAppProvider),
      ]) {
        expect(state.hasError, isTrue);
        expect(state.error, isA<IdentityStoreException>());
        expect(state.isLoading, isFalse);
      }
    },
  );

  test('volume_power_and_current_app_follow_session_events', () async {
    await repo.upsert(savedTv(name: 'a'));
    final c = makeContainer()
      ..listen(volumeProvider, (_, _) {})
      ..listen(powerStateProvider, (_, _) {})
      ..listen(currentAppProvider, (_, _) {});
    expect(await c.read(volumeProvider.future), isNull);
    expect(await c.read(powerStateProvider.future), isNull);
    expect(await c.read(currentAppProvider.future), isNull);

    final session = (await c.read(remoteSessionProvider.future))!;
    await untilConnected(session);
    clients.created.last
      ..push(const VolumeChanged(12, 100, false))
      ..push(const PowerStateChanged(true))
      ..push(const CurrentAppChanged('com.netflix.ninja'));
    await pumpEventQueue();
    expect(c.read(volumeProvider).value, const VolumeChanged(12, 100, false));
    expect(c.read(powerStateProvider).value, isTrue);
    expect(c.read(currentAppProvider).value, 'com.netflix.ninja');

    clients.created.last.push(const PowerStateChanged(false));
    await pumpEventQueue();
    expect(c.read(powerStateProvider).value, isFalse);
  });

  test('values_cached_before_a_provider_is_read_are_replayed', () async {
    await repo.upsert(savedTv(name: 'a'));
    final c = makeContainer()..listen(currentAppProvider, (_, _) {});
    final session = (await c.read(remoteSessionProvider.future))!;
    await untilConnected(session);
    clients.created.last.push(const CurrentAppChanged('com.example'));
    await pumpEventQueue();
    // A rebuilt provider starts from the session's cached value.
    c.invalidate(currentAppProvider);
    expect(await c.read(currentAppProvider.future), 'com.example');
  });

  test('volume_power_and_current_app_are_null_without_a_session', () async {
    final c = makeContainer()
      ..listen(volumeProvider, (_, _) {})
      ..listen(powerStateProvider, (_, _) {})
      ..listen(currentAppProvider, (_, _) {});
    expect(await c.read(volumeProvider.future), isNull);
    expect(await c.read(powerStateProvider.future), isNull);
    expect(await c.read(currentAppProvider.future), isNull);
  });

  test('disposing_the_container_disposes_the_session', () async {
    await repo.upsert(savedTv(name: 'a'));
    final c = ProviderContainer(overrides: overrides());
    final session = (await c.read(remoteSessionProvider.future))!;
    await untilConnected(session);
    c.dispose();
    await pumpEventQueue();
    expect(clients.created.single.closed, isTrue);
  });

  test('saved_devices_follow_the_repository', () async {
    final c = makeContainer()..listen(savedDevicesProvider, (_, _) {});
    expect(await c.read(savedDevicesProvider.future), isEmpty);
    await repo.upsert(savedTv(name: 'a'));
    await pumpEventQueue();
    expect(c.read(savedDevicesProvider).value!.map((d) => d.serviceName), [
      'a',
    ]);
  });

  test('remote_client_factory_builds_a_client_with_the_flavor_info', () {
    final c = ProviderContainer.test(
      overrides: [flavorProvider.overrideWithValue(Flavor.prod)],
    );
    final client = c.read(remoteClientFactoryProvider)(
      host: '10.0.0.5',
      port: 6467,
      identity: testIdentity(),
    );
    expect(client.host, '10.0.0.5');
    expect(client.port, 6467);
    final expected = deviceInfoFor(Flavor.prod);
    expect(client.deviceInfo.packageName, expected.packageName);
    expect(client.deviceInfo.model, expected.model);
    expect(client.deviceInfo.vendor, expected.vendor);
    expect(client.deviceInfo.appVersion, expected.appVersion);
  });

  group('lifecycle', () {
    const quick = SessionTiming(
      backgroundGrace: Duration(milliseconds: 20),
      nudgeDebounce: Duration(milliseconds: 5),
    );

    /// Waits until [session] reports `disconnected`. Event-driven, so it does
    /// not depend on how long the machine takes; the timeout only bounds a
    /// failing run.
    Future<void> untilDisconnected(RemoteSession session) => session.states
        .firstWhere((s) => s.status == ConnectionStatus.disconnected)
        .timeout(const Duration(seconds: 5));

    test('session_disconnects_after_background_grace', () async {
      await repo.upsert(savedTv(name: 'a'));
      final c = makeContainer(timing: quick)
        ..listen(remoteSessionProvider, (_, _) {});
      final session = (await c.read(remoteSessionProvider.future))!;
      await untilConnected(session);

      signals.background();
      await untilDisconnected(session);

      expect(clients.created.single.closed, isTrue);
      expect(session.current.status, ConnectionStatus.disconnected);
    });

    test('foreground_after_grace_connects_again', () async {
      await repo.upsert(savedTv(name: 'a'));
      final c = makeContainer(timing: quick)
        ..listen(remoteSessionProvider, (_, _) {});
      final session = (await c.read(remoteSessionProvider.future))!;
      await untilConnected(session);
      signals.background();
      await untilDisconnected(session);

      signals.foreground();
      await untilConnected(session);

      expect(clients.created, hasLength(2));
      expect(clients.created.first.closed, isTrue);
      expect(clients.created.last.closed, isFalse);
    });

    test('rebuilding_the_session_stops_the_old_supervisor', () async {
      await repo.upsert(savedTv(name: 'a'));
      final c = makeContainer(timing: quick)
        ..listen(remoteSessionProvider, (_, _) {});
      final first = (await c.read(remoteSessionProvider.future))!;
      await untilConnected(first);
      expect(
        (signals.visibilityListeners, signals.networkListeners),
        (1, 1),
      );

      c.read(activeTargetProvider.notifier).activateDevice('a');
      final second = (await c.read(remoteSessionProvider.future))!;
      await untilConnected(second);

      // The old supervisor was disposed with its session: only one remains.
      expect(
        (signals.visibilityListeners, signals.networkListeners),
        (1, 1),
      );
      signals.background();
      await untilDisconnected(second);
      expect(first.current.status, isNot(ConnectionStatus.connected));
      expect(clients.created.where((x) => !x.closed), isEmpty);
    });

    test('no_saved_device_creates_no_supervisor_work', () async {
      final c = makeContainer(timing: quick)
        ..listen(remoteSessionProvider, (_, _) {});
      expect(await c.read(remoteSessionProvider.future), isNull);
      signals
        ..background()
        ..networkChanged();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(clients.created, isEmpty);
    });
  });

  test('no_retry_never_schedules_a_retry', () {
    expect(noRetry(0, Exception('x')), isNull);
    expect(noRetry(5, Exception('x')), isNull);
  });
}
