import 'package:atv_remote/atv_remote.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/session/remote_session.dart';
import 'package:tv_remote/core/session/tv_remote_session.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/device_repository.dart';
import 'package:tv_remote/core/tv/host_resolver.dart';
import 'package:tv_remote/core/tv/saved_device_x.dart';

import '../../helpers/fake_remote_client.dart';
import '../../helpers/test_devices.dart';
import '../../helpers/test_identity.dart';

/// Waits until [s] reports [st], then lets pending storage writes finish.
Future<void> until(RemoteSession s, ConnectionStatus st) async {
  await s.states
      .firstWhere((state) => state.status == st)
      .timeout(const Duration(seconds: 5));
  await pumpEventQueue();
}

void main() {
  final fixedNow = DateTime.utc(2026, 10, 25, 21, 15);
  late AppDatabase db;
  late DriftDeviceRepository repo;
  late FakeRemoteClients clients;
  final sessions = <RemoteSession>[];

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftDeviceRepository(db);
    clients = FakeRemoteClients();
  });
  tearDown(() async {
    for (final s in sessions) {
      await s.dispose();
    }
    sessions.clear();
    await db.close();
  });

  TvRemoteSession session(SavedDevice device, {HostResolver? resolveHost}) {
    final s = TvRemoteSession(
      device: device,
      identity: testIdentity(),
      devices: repo,
      clientFactory: clients.create,
      resolveHost: resolveHost ?? (_) async => null,
      backoff: Backoff(
        initial: const Duration(milliseconds: 1),
        max: const Duration(milliseconds: 1),
      ),
      now: () => fixedNow,
    );
    sessions.add(s);
    return s;
  }

  test('connects_with_the_stored_pin_and_marks_the_device_connected', () async {
    await repo.upsert(savedTv(at: DateTime.utc(2026)));
    final s = session(savedTv());
    await s.connect();
    await until(s, ConnectionStatus.connected);
    final d = (await repo.find('Living Room TV 3'))!;
    expect(d.lastConnectedAt, fixedNow.toUtc());
    expect(d.lastHost, '192.168.0.20');
    expect(d.serverKeyPin, testPin);
    expect(clients.created.single.port, 6466);
    expect(clients.created.single.identity, same(testIdentity()));
    expect(s.tvName, 'Living Room TV 3');
    expect(s.isDemo, isFalse);
    expect(s.pairingTarget!.serviceName, 'Living Room TV 3');
  });

  test('re_resolves_host_on_reconnect', () async {
    clients.outcomes['192.168.0.20'] = FakeConnect.networkError;
    await repo.upsert(savedTv());
    final s = session(
      savedTv(),
      resolveHost: (name) async =>
          name == 'Living Room TV 3' ? '192.168.0.99' : null,
    );
    await s.connect();
    await until(s, ConnectionStatus.connected);
    expect(clients.created.map((c) => c.host), [
      '192.168.0.20',
      '192.168.0.99',
    ]);
    expect((await repo.find('Living Room TV 3'))!.lastHost, '192.168.0.99');
  });

  test('identity_changed_clears_pin_and_reports_server_key_changed', () async {
    clients = FakeRemoteClients(serverKey: List<int>.filled(32, 9));
    await repo.upsert(savedTv());
    final s = session(savedTv());
    await s.connect();
    await until(s, ConnectionStatus.needsPairing);
    expect(s.current.status, ConnectionStatus.needsPairing);
    expect(s.current.lastError, RemoteCloseReason.serverKeyChanged);
    expect((await repo.find('Living Room TV 3'))!.serverKeyPin, isNull);
    expect(clients.created, hasLength(1));

    await s.connect();
    s
      ..reconnect()
      ..notifyAppResumed()
      ..notifyNetworkChanged();
    await pumpEventQueue();
    expect(clients.created, hasLength(1));
    expect(s.current.lastError, RemoteCloseReason.serverKeyChanged);
  });

  test('missing_pin_needs_pairing_without_connecting', () async {
    await repo.upsert(savedTv(noPin: true));
    final s = session(savedTv(noPin: true));
    expect(s.current.status, ConnectionStatus.needsPairing);
    await s.connect();
    s
      ..reconnect()
      ..notifyAppResumed()
      ..notifyNetworkChanged();
    await s.disconnect();
    await pumpEventQueue();
    expect(clients.created, isEmpty);
    expect(s.current.status, ConnectionStatus.needsPairing);
    expect(
      await s.states.first,
      const TvConnectionState(status: ConnectionStatus.needsPairing),
    );
  });

  test('certificate_rejection_needs_pairing_and_keeps_pin', () async {
    clients.defaultOutcome = FakeConnect.certificateRejected;
    await repo.upsert(savedTv());
    final s = session(savedTv());
    await s.connect();
    await until(s, ConnectionStatus.needsPairing);
    expect(s.current.status, ConnectionStatus.needsPairing);
    expect(s.current.lastError, RemoteCloseReason.certificateRejected);
    expect((await repo.find('Living Room TV 3'))!.serverKeyPin, testPin);
  });

  test('manual_device_is_never_re_resolved', () async {
    clients.outcomes['192.168.0.5'] = FakeConnect.networkError;
    final tv = savedTv(name: 'manual:192.168.0.5', host: '192.168.0.5');
    await repo.upsert(tv);
    var resolveCalls = 0;
    final s = session(
      tv,
      resolveHost: (_) async {
        resolveCalls++;
        return '192.168.0.99';
      },
    );
    await s.connect();
    await until(s, ConnectionStatus.offline);
    expect(resolveCalls, 0);
    expect(clients.created, isNotEmpty);
    expect(clients.created.map((c) => c.host).toSet(), {'192.168.0.5'});
  });

  test('events_update_volume_power_and_current_app', () async {
    final s = session(savedTv());
    final seen = <RemoteEvent>[];
    s.events.listen(seen.add);
    expect((s.volume, s.isPowerOn, s.currentApp), (null, null, null));
    await s.connect();
    await until(s, ConnectionStatus.connected);

    clients.created.last
      ..push(const VolumeChanged(8, 20, false))
      ..push(const PowerStateChanged(true))
      ..push(const CurrentAppChanged('com.netflix.ninja'));
    await pumpEventQueue();

    expect(s.volume, const VolumeChanged(8, 20, false));
    expect(s.isPowerOn, isTrue);
    expect(s.currentApp, 'com.netflix.ninja');
    expect(seen, const [
      VolumeChanged(8, 20, false),
      PowerStateChanged(true),
      CurrentAppChanged('com.netflix.ninja'),
    ]);
  });

  test('states_replays_current_to_new_listeners', () async {
    final s = session(savedTv());
    expect(
      await s.states.first,
      const TvConnectionState(status: ConnectionStatus.disconnected),
    );
    await s.connect();
    await until(s, ConnectionStatus.connected);
    expect(
      await s.states.first,
      const TvConnectionState(status: ConnectionStatus.connected),
    );
    expect(s.current.status, ConnectionStatus.connected);

    final seen = <ConnectionStatus>[];
    final sub = s.states.listen((state) => seen.add(state.status));
    await pumpEventQueue();
    clients.created.last.drop();
    // Right after the drop `current` is still connected, so wait for the
    // loss first.
    await until(s, ConnectionStatus.reconnecting);
    await until(s, ConnectionStatus.connected);
    await sub.cancel();
    expect(seen, [
      ConnectionStatus.connected,
      ConnectionStatus.reconnecting,
      ConnectionStatus.connected,
    ]);
  });

  test(
    'reconnect_from_disconnected_connects_and_otherwise_notifies',
    () async {
      final s = session(savedTv());
      await s.connect();
      await until(s, ConnectionStatus.connected);
      await s.disconnect();
      await until(s, ConnectionStatus.disconnected);
      expect(clients.created.single.closed, isTrue);

      s.reconnect();
      await until(s, ConnectionStatus.connected);
      expect(clients.created, hasLength(2));

      // Otherwise it nudges: from offline that is a fresh attempt.
      clients.defaultOutcome = FakeConnect.networkError;
      clients.created.last.drop();
      await until(s, ConnectionStatus.offline);
      final before = clients.created.length;
      clients.defaultOutcome = FakeConnect.succeed;
      s.reconnect();
      await until(s, ConnectionStatus.connected);
      expect(clients.created, hasLength(before + 1));
    },
  );

  test('disconnect_keeps_needs_pairing_and_offline', () async {
    clients.defaultOutcome = FakeConnect.certificateRejected;
    final s = session(savedTv());
    await s.connect();
    await until(s, ConnectionStatus.needsPairing);
    await s.disconnect();
    await pumpEventQueue();
    expect(s.current.status, ConnectionStatus.needsPairing);
    expect(s.current.lastError, RemoteCloseReason.certificateRejected);

    clients.defaultOutcome = FakeConnect.networkError;
    await s.connect();
    await until(s, ConnectionStatus.offline);
    await s.disconnect();
    await pumpEventQueue();
    expect(s.current.status, ConnectionStatus.offline);
  });

  test('commands_while_not_connected_throw_not_connected', () async {
    final s = session(savedTv());
    expect(
      () => s.sendKey(KeyCodes.home),
      throwsA(isA<NotConnectedException>()),
    );
    expect(
      () => s.launchAppLink('https://www.netflix.com/title'),
      throwsA(isA<NotConnectedException>()),
    );
    expect(() => s.sendText('hi'), throwsA(isA<NotConnectedException>()));

    final noPin = session(savedTv(noPin: true));
    expect(
      () => noPin.sendKey(KeyCodes.home),
      throwsA(isA<NotConnectedException>()),
    );
    expect(
      () => noPin.launchAppLink('x'),
      throwsA(isA<NotConnectedException>()),
    );
    expect(() => noPin.sendText('x'), throwsA(isA<NotConnectedException>()));

    await s.connect();
    await until(s, ConnectionStatus.connected);
    s
      ..sendKey(KeyCodes.home)
      ..sendKey(KeyCodes.home, direction: KeyDirection.startLong)
      ..launchAppLink('https://www.netflix.com/title')
      ..sendText('hi');
    final client = clients.created.single;
    expect(client.sentKeys, [
      (KeyCodes.home, KeyDirection.short),
      (KeyCodes.home, KeyDirection.startLong),
    ]);
    expect(client.sentLinks, ['https://www.netflix.com/title']);
    expect(client.sentTexts, ['hi']);
  });

  test('dispose_is_idempotent_and_closes_the_client', () async {
    final s = session(savedTv());
    await s.connect();
    await until(s, ConnectionStatus.connected);
    var statesDone = false;
    var eventsDone = false;
    s.states.listen(null, onDone: () => statesDone = true);
    s.events.listen(null, onDone: () => eventsDone = true);

    await Future.wait([s.dispose(), s.dispose()]);
    await s.dispose();
    await pumpEventQueue();
    expect(clients.created.single.closed, isTrue);
    expect(s.current.status, ConnectionStatus.disconnected);
    expect((statesDone, eventsDone), (true, true));
    expect(
      () => s.sendKey(KeyCodes.home),
      throwsA(isA<NotConnectedException>()),
    );
    await s.connect();
    expect(clients.created, hasLength(1));

    final noPin = session(savedTv(noPin: true));
    await noPin.dispose();
    await noPin.dispose();
  });

  test('saved_device_label_and_discovered_tv', () {
    final tv = savedTv(nickname: 'Lounge');
    expect(tv.label, 'Lounge');
    expect(savedTv().label, 'Living Room TV 3');
    final d = tv.toDiscoveredTv();
    expect(d.serviceName, 'Living Room TV 3');
    expect(d.displayName, 'Lounge');
    expect(d.host, '192.168.0.20');
    expect(d.port, 6466);
    expect(d.isLegacyService, isFalse);
  });
}
