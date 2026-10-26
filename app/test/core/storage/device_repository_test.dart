import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/device_repository.dart';

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
    await repo.clearServerKeyPin('a');
    expect(
      await repo.find('a'),
      a.copyWith(serverKeyPin: const Value(null)),
    );
  });

  test('updates_on_unknown_device_are_no_ops', () async {
    await repo.upsert(dev('a', pin: 'ab12'));
    await repo.markConnected(
      'zzz',
      host: '192.168.0.99',
      at: DateTime.utc(2027),
    );
    await repo.clearServerKeyPin('zzz');
    expect(await repo.find('zzz'), isNull);
    expect(await repo.watchAll().first, [dev('a', pin: 'ab12')]);
  });
}
