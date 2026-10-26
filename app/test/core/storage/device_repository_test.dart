import 'package:atv_remote/atv_remote.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/device_repository.dart';

import '../../helpers/test_devices.dart';

SavedDevice dev(String name, {int minute = 0, String? pin}) => SavedDevice(
  serviceName: name,
  displayName: 'TV $name',
  lastHost: '192.168.0.10',
  port: 6466,
  serverKeyPin: pin,
  lastConnectedAt: DateTime.utc(2026, 10, 25, 12, minute),
);

void main() {
  late AppDatabase db;
  late DriftDeviceRepository repo;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftDeviceRepository(db);
  });
  tearDown(() => db.close());

  test('device_upsert_and_watch', () async {
    final seen = expectLater(
      repo.watchAll(),
      emitsInOrder([
        isEmpty,
        [dev('a')],
      ]),
    );
    // Let the initial (empty) query emit before writing; drift drops a first
    // result that a write invalidates mid-flight.
    await pumpEventQueue();
    await repo.upsert(dev('a'));
    await seen;
  });

  test('upsert_replaces_device_with_same_service_name', () async {
    await repo.upsert(dev('a'));
    await repo.upsert(dev('a').copyWith(nickname: const Value('Bedroom')));
    final all = await repo.watchAll().first;
    expect(all, hasLength(1));
    expect(all.single.nickname, 'Bedroom');
  });

  test('watch_all_orders_by_last_connected_desc', () async {
    await repo.upsert(dev('a', minute: 1));
    await repo.upsert(dev('b', minute: 3));
    await repo.upsert(dev('c', minute: 2));
    final all = await repo.watchAll().first;
    expect(all.map((d) => d.serviceName), ['b', 'c', 'a']);
  });

  test('last_used_returns_most_recent_or_null', () async {
    expect(await repo.lastUsed(), isNull);
    await repo.upsert(dev('a', minute: 1));
    await repo.upsert(dev('b', minute: 3));
    expect((await repo.lastUsed())!.serviceName, 'b');
  });

  test('delete_removes_device_and_ignores_unknown', () async {
    await repo.upsert(dev('a'));
    await repo.delete('a');
    expect(await repo.watchAll().first, isEmpty);
    await repo.delete('zzz');
  });

  test('nullable_fields_round_trip', () async {
    final full = dev('a', pin: 'ab12cd34').copyWith(
      wolMac: const Value('AA:BB:CC:DD:EE:FF'),
      nickname: const Value('Lounge'),
    );
    await repo.upsert(full);
    expect(await repo.lastUsed(), full);

    final bare = dev('a');
    await repo.upsert(bare);
    final read = (await repo.lastUsed())!;
    expect(read.serverKeyPin, isNull);
    expect(read.wolMac, isNull);
    expect(read.nickname, isNull);
  });

  test('last_connected_at_round_trips_to_the_second', () async {
    await repo.upsert(dev('a', minute: 7));
    expect(
      (await repo.lastUsed())!.lastConnectedAt.isAtSameMomentAs(
        DateTime.utc(2026, 10, 25, 12, 7),
      ),
      isTrue,
    );
  });

  test('find_returns_device_or_null', () async {
    expect(await repo.find('a'), isNull);
    final a = dev('a', pin: 'ab12');
    await repo.upsert(a);
    await repo.upsert(dev('b'));
    expect(await repo.find('a'), a);
    expect((await repo.find('a'))!.lastConnectedAt.isUtc, isTrue);
    expect(await repo.find('zzz'), isNull);
  });

  test('mark_connected_updates_only_host_and_time', () async {
    final a = dev('a', pin: 'ab12').copyWith(
      nickname: const Value('Lounge'),
      wolMac: const Value('AA:BB:CC:DD:EE:FF'),
    );
    await repo.upsert(a);
    final at = DateTime.utc(2026, 10, 26, 8, 30);
    await repo.markConnected('a', host: '192.168.0.99', at: at);
    final read = (await repo.find('a'))!;
    expect(read.lastHost, '192.168.0.99');
    expect(read.lastConnectedAt, at);
    expect(
      read,
      a.copyWith(lastHost: '192.168.0.99', lastConnectedAt: at),
    );
  });

  test('clear_server_key_pin_keeps_other_fields', () async {
    final a = dev('a', pin: 'ab12').copyWith(
      nickname: const Value('Lounge'),
      wolMac: const Value('AA:BB:CC:DD:EE:FF'),
    );
    await repo.upsert(a);
    await repo.clearServerKeyPin('a', distrustedPin: 'ab12');
    expect(
      await repo.find('a'),
      a.copyWith(serverKeyPin: const Value(null)),
    );
  });

  test('clear_server_key_pin_leaves_a_newer_pin_alone', () async {
    await repo.upsert(dev('a', pin: 'bb22'));
    await repo.clearServerKeyPin('a', distrustedPin: 'aa11');
    expect((await repo.find('a'))!.serverKeyPin, 'bb22');

    await repo.clearServerKeyPin('a', distrustedPin: 'bb22');
    expect((await repo.find('a'))!.serverKeyPin, isNull);
  });

  test('updates_on_unknown_device_are_no_ops', () async {
    await repo.upsert(dev('a', pin: 'ab12'));
    await repo.markConnected(
      'zzz',
      host: '192.168.0.99',
      at: DateTime.utc(2027),
    );
    await repo.clearServerKeyPin('zzz', distrustedPin: 'ab12');
    expect(await repo.find('zzz'), isNull);
    expect(await repo.watchAll().first, [dev('a', pin: 'ab12')]);
  });

  test('set_wol_mac_updates_only_the_mac', () async {
    final a = dev('a', pin: 'ab12').copyWith(nickname: const Value('Lounge'));
    await repo.upsert(a);
    await repo.setWolMac('a', 'AA:BB:CC:DD:EE:F0');
    expect(
      await repo.find('a'),
      a.copyWith(wolMac: const Value('AA:BB:CC:DD:EE:F0')),
    );
    await repo.setWolMac('a', null);
    expect(await repo.find('a'), a);
  });

  test('set_wol_mac_on_unknown_device_is_a_no_op', () async {
    await repo.upsert(dev('a'));
    await repo.setWolMac('zzz', 'AA:BB:CC:DD:EE:F0');
    expect(await repo.find('zzz'), isNull);
    expect(await repo.watchAll().first, [dev('a')]);
  });

  test('set_last_host_updates_only_the_host', () async {
    final a = dev('a', pin: 'ab12').copyWith(
      nickname: const Value('Lounge'),
      wolMac: const Value('AA:BB:CC:DD:EE:FF'),
    );
    await repo.upsert(a);
    await repo.setLastHost('a', '192.168.0.33');
    final read = (await repo.find('a'))!;
    expect(read.lastHost, '192.168.0.33');
    expect(read, a.copyWith(lastHost: '192.168.0.33'));
    expect(read.lastConnectedAt, a.lastConnectedAt);
  });

  test('set_last_host_on_unknown_device_is_a_no_op', () async {
    await repo.upsert(dev('a'));
    await repo.setLastHost('zzz', '192.168.0.33');
    expect(await repo.find('zzz'), isNull);
    expect(await repo.watchAll().first, [dev('a')]);
  });

  const mdnsTv = DiscoveredTv(
    serviceName: 'Living Room TV 3',
    displayName: 'Living Room TV 3',
    host: '192.168.0.20',
    port: 6466,
    isLegacyService: false,
  );

  test('adopt_manual_device_moves_trust_to_the_mdns_name', () async {
    await repo.upsert(
      savedTv(
        name: 'manual:192.168.0.20',
        nickname: 'Den',
        wolMac: 'AA:BB:CC:DD:EE:F0',
      ),
    );
    final ok = await repo.adoptManualDevice(
      manualServiceName: 'manual:192.168.0.20',
      tv: mdnsTv,
    );
    expect(ok, isTrue);
    expect(await repo.find('manual:192.168.0.20'), isNull);
    final moved = (await repo.find('Living Room TV 3'))!;
    expect(
      (moved.nickname, moved.wolMac, moved.serverKeyPin, moved.displayName),
      ('Den', 'AA:BB:CC:DD:EE:F0', testPin, 'Living Room TV 3'),
    );
    expect(moved.lastHost, '192.168.0.20');
    expect(moved.port, 6466);
    expect(moved.lastConnectedAt, DateTime.utc(2026, 10, 25));
    expect(await repo.watchAll().first, hasLength(1));
  });

  test(
    'adopt_manual_device_refuses_when_the_mdns_name_is_already_saved',
    () async {
      final manual = savedTv(name: 'manual:192.168.0.20', nickname: 'Den');
      final named = savedTv(pin: 'other-pin');
      await repo.upsert(manual);
      await repo.upsert(named);
      final ok = await repo.adoptManualDevice(
        manualServiceName: 'manual:192.168.0.20',
        tv: mdnsTv,
      );
      expect(ok, isFalse);
      expect(await repo.find('manual:192.168.0.20'), manual);
      expect(await repo.find('Living Room TV 3'), named);
    },
  );

  test('adopt_manual_device_is_a_no_op_for_unknown_rows', () async {
    await repo.upsert(dev('a'));
    final ok = await repo.adoptManualDevice(
      manualServiceName: 'manual:192.168.0.99',
      tv: mdnsTv,
    );
    expect(ok, isFalse);
    expect(await repo.find('Living Room TV 3'), isNull);
    expect(await repo.watchAll().first, [dev('a')]);
  });
}
