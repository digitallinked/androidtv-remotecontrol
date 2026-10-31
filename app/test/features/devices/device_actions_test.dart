import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/session/remote_client_factory.dart';
import 'package:tv_remote/core/session/remote_session.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/session/session_signals.dart';
import 'package:tv_remote/core/session/session_target.dart';
import 'package:tv_remote/core/storage/identity_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/core/tv/host_resolver.dart';
import 'package:tv_remote/features/devices/application/device_actions.dart';
import 'package:tv_remote/features/discovery/data/discovery_providers.dart';
import 'package:tv_remote/features/pairing/data/pairing_providers.dart';

import '../../helpers/fake_remote_client.dart';
import '../../helpers/in_memory_device_repository.dart';
import '../../helpers/manual_session_signals.dart';
import '../../helpers/test_devices.dart';
import '../../helpers/test_identity.dart';

void main() {
  late InMemoryDeviceRepository repo;
  late FakeRemoteClients clients;
  late IdentityStore identityStore;

  setUp(() {
    repo = InMemoryDeviceRepository([
      savedTv(name: 'A', at: DateTime.utc(2026, 10, 25, 12, 3)),
      savedTv(
        name: 'B',
        host: '192.168.0.21',
        at: DateTime.utc(2026, 10, 25, 12, 1),
      ),
    ]);
    clients = FakeRemoteClients();
    identityStore = testIdentityStore();
  });

  ProviderContainer makeContainer() => ProviderContainer.test(
    overrides: [
      deviceRepositoryProvider.overrideWithValue(repo),
      identityStoreProvider.overrideWithValue(identityStore),
      remoteClientFactoryProvider.overrideWithValue(clients.create),
      hostResolverProvider.overrideWithValue((_) async => null),
      sessionSignalsProvider.overrideWithValue(ManualSessionSignals()),
    ],
  )..listen(remoteSessionProvider, (_, _) {});

  Future<String?> sessionTv(ProviderContainer c) async =>
      (await c.read(remoteSessionProvider.future))?.pairingTarget?.serviceName;

  test('deleting_the_active_tv_switches_to_the_next_saved_tv', () async {
    final c = makeContainer();
    c.read(activeTargetProvider.notifier).activateDevice('A');
    final old = (await c.read(remoteSessionProvider.future))!;
    expect(old.pairingTarget!.serviceName, 'A');
    final identity = (await identityStore.loadOrCreate()).certificatePem;

    await c.read(deviceActionsProvider).delete('A');

    expect(c.read(activeTargetProvider), isNull);
    expect(await sessionTv(c), 'B');
    expect(await c.read(remoteSessionProvider.future), isNot(same(old)));
    // The old session was closed with its provider state.
    expect(clients.created.first.closed, isTrue);
    expect(repo.saved.keys, ['B']);
    // The client identity is shared by every TV: it is never touched.
    expect((await identityStore.loadOrCreate()).certificatePem, identity);
  });

  test('deleting_the_tv_the_session_follows_by_default_moves_on', () async {
    // No explicit target: the session follows the most recent TV, A.
    final c = makeContainer();
    expect(c.read(activeTargetProvider), isNull);
    expect(await sessionTv(c), 'A');

    await c.read(deviceActionsProvider).delete('A');

    expect(await sessionTv(c), 'B');
  });

  test('deleting_the_last_tv_leaves_no_session', () async {
    repo = InMemoryDeviceRepository([savedTv(name: 'A')]);
    final c = makeContainer();
    c.read(activeTargetProvider.notifier).activateDevice('A');
    expect(await sessionTv(c), 'A');

    await c.read(deviceActionsProvider).delete('A');

    expect(c.read(activeTargetProvider), isNull);
    expect(await c.read(remoteSessionProvider.future), isNull);
  });

  test('deleting_another_tv_keeps_the_session', () async {
    final c = makeContainer();
    c.read(activeTargetProvider.notifier).activateDevice('A');
    final session = await c.read(remoteSessionProvider.future);

    await c.read(deviceActionsProvider).delete('B');

    expect(c.read(activeTargetProvider), const DeviceTarget('A'));
    expect(await c.read(remoteSessionProvider.future), same(session));
    expect(clients.created.single.closed, isFalse);
    expect(repo.saved.keys, ['A']);
  });

  test('deleting_a_tv_during_the_demo_keeps_the_demo', () async {
    final c = makeContainer();
    c.read(activeTargetProvider.notifier).startDemo();
    final demo = (await c.read(remoteSessionProvider.future))!;
    expect(demo, isA<RemoteSession>());

    await c.read(deviceActionsProvider).delete('A');

    expect(c.read(activeTargetProvider), const DemoTarget());
    expect(await c.read(remoteSessionProvider.future), same(demo));
  });

  test('a_failed_delete_leaves_the_session_alone', () async {
    final c = makeContainer();
    c.read(activeTargetProvider.notifier).activateDevice('A');
    final session = await c.read(remoteSessionProvider.future);
    repo.failNextWrite = StateError('disk');

    await expectLater(
      c.read(deviceActionsProvider).delete('A'),
      throwsStateError,
    );

    expect(c.read(activeTargetProvider), const DeviceTarget('A'));
    expect(await c.read(remoteSessionProvider.future), same(session));
    expect(repo.saved.keys, containsAll(['A', 'B']));
  });

  test('rename_trims_and_empty_clears', () async {
    final c = makeContainer();
    final actions = c.read(deviceActionsProvider);

    await actions.rename('A', '  Bedroom  ');
    expect(repo.saved['A']!.nickname, 'Bedroom');
    await actions.rename('A', '   ');
    expect(repo.saved['A']!.nickname, isNull);
    await actions.rename('A', 'Den');
    await actions.rename('A', null);
    expect(repo.saved['A']!.nickname, isNull);
    // The TV's own name is untouched.
    expect(repo.saved['A']!.displayName, 'A');
  });

  test('set_wol_mac_stores_and_clears_the_address', () async {
    final c = makeContainer();
    final actions = c.read(deviceActionsProvider);

    await actions.setWolMac('A', 'AA:BB:CC:DD:EE:F0');
    expect(repo.saved['A']!.wolMac, 'AA:BB:CC:DD:EE:F0');
    await actions.setWolMac('A', null);
    expect(repo.saved['A']!.wolMac, isNull);
  });

  test('actions_taken_before_an_await_still_write_afterwards', () async {
    // The edit page saves a new name and a new MAC with one Save: it takes
    // the actions once and awaits the first write. Nothing watches the
    // provider, so it is disposed in between.
    final c = makeContainer();
    final actions = c.read(deviceActionsProvider);

    await actions.rename('A', 'Den');
    await pumpEventQueue();
    expect(c.exists(deviceActionsProvider), isFalse);
    await actions.setWolMac('A', 'AA:BB:CC:DD:EE:F0');

    expect(repo.saved['A']!.nickname, 'Den');
    expect(repo.saved['A']!.wolMac, 'AA:BB:CC:DD:EE:F0');

    // Removing works through the same held actions.
    await actions.delete('B');
    expect(repo.saved.keys, ['A']);
  });

  test('write_errors_propagate', () async {
    final c = makeContainer();
    final actions = c.read(deviceActionsProvider);
    repo.failNextWrite = StateError('disk');
    await expectLater(actions.rename('A', 'x'), throwsStateError);
    repo.failNextWrite = StateError('disk');
    await expectLater(actions.setWolMac('A', null), throwsStateError);
  });

  test('pair_again_uses_the_saved_host_when_the_resolver_throws', () async {
    // "Pair again" looks the TV up afresh (decision #33); a look-up that
    // throws, at once or later, counts as "not found" (Ruling P8-R10).
    for (final resolver in <HostResolver>[
      (_) async => throw StateError('nsd failed'),
      (_) => throw StateError('nsd failed'),
    ]) {
      final c = ProviderContainer.test(
        overrides: [
          deviceRepositoryProvider.overrideWithValue(repo),
          hostResolverProvider.overrideWithValue(resolver),
        ],
      );
      final sub = c.listen(pairingTargetProvider('B'), (_, _) {});
      final target = await c.read(pairingTargetProvider('B').future);
      expect(target!.serviceName, 'B');
      expect(target.host, '192.168.0.21');
      sub.close();
    }
  });
}
