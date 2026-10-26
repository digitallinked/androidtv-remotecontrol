import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/discovery/data/discovery_providers.dart';
import 'package:tv_remote/features/pairing/data/pairing_providers.dart';

import '../../helpers/in_memory_device_repository.dart';
import '../../helpers/test_devices.dart';

void main() {
  late InMemoryDeviceRepository repo;
  late List<String> resolved;

  setUp(() {
    repo = InMemoryDeviceRepository();
    resolved = [];
  });

  /// A container whose host resolver answers [host] (`null`: not found).
  ProviderContainer containerWith(String? host) => ProviderContainer.test(
    overrides: [
      deviceRepositoryProvider.overrideWithValue(repo),
      hostResolverProvider.overrideWithValue((name) async {
        resolved.add(name);
        return host;
      }),
    ],
  );

  test('pairing_target_re_resolves_a_saved_tv', () async {
    await repo.upsert(savedTv(nickname: 'Bedroom'));
    final c = containerWith('192.168.0.33');
    final target = await c.read(
      pairingTargetProvider('Living Room TV 3').future,
    );
    expect(target!.host, '192.168.0.33');
    expect(target.displayName, 'Living Room TV 3');
    expect(target.serviceName, 'Living Room TV 3');
    expect(resolved, ['Living Room TV 3']);
  });

  test('pairing_target_falls_back_to_the_saved_host', () async {
    await repo.upsert(savedTv());
    final c = containerWith(null);
    final target = await c.read(
      pairingTargetProvider('Living Room TV 3').future,
    );
    expect(target!.host, '192.168.0.20');
    expect(resolved, ['Living Room TV 3']);
  });

  test('manual_tv_is_never_re_resolved', () async {
    await repo.upsert(savedTv(name: 'manual:192.168.0.20'));
    final c = containerWith('192.168.0.33');
    final target = await c.read(
      pairingTargetProvider('manual:192.168.0.20').future,
    );
    expect(target!.host, '192.168.0.20');
    expect(resolved, isEmpty);
  });

  test('unsaved_name_still_resolves_on_the_network', () async {
    final c = containerWith('192.168.0.44');
    final target = await c.read(pairingTargetProvider('Attic TV').future);
    expect(target!.host, '192.168.0.44');
    expect(target.displayName, 'Attic TV');
    expect(target.port, 6466);
    expect(resolved, ['Attic TV']);

    final missing = containerWith(null);
    expect(await missing.read(pairingTargetProvider('Nope').future), isNull);
  });
}
