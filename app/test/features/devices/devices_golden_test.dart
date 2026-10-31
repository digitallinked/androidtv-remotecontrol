@Tags(['golden'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/core/tv/saved_device_x.dart';
import 'package:tv_remote/features/devices/presentation/devices_screen.dart';
import 'package:tv_remote/features/devices/presentation/edit_device_screen.dart';

import '../../helpers/fake_remote_session.dart';
import '../../helpers/in_memory_device_repository.dart';
import '../../helpers/pump_router_app.dart';
import '../../helpers/test_devices.dart';

void main() {
  // One nicknamed TV that is in use, and one that was never paired.
  Future<void> pump(
    WidgetTester t, {
    required String location,
    required Brightness brightness,
  }) {
    t.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final lounge = savedTv(
      nickname: 'Lounge',
      at: DateTime.utc(2026, 10, 25, 12, 5),
    ).copyWith(wolMac: const Value('AA:BB:CC:DD:EE:F0'));
    final repo = InMemoryDeviceRepository([
      lounge,
      savedTv(
        name: 'Bedroom TV',
        host: '192.168.0.21',
        noPin: true,
        at: DateTime.utc(2026, 10, 25, 12, 1),
      ),
    ]);
    return pumpRouterApp(
      t,
      initialLocation: location,
      brightness: brightness,
      overrides: [
        deviceRepositoryProvider.overrideWithValue(repo),
        savedDevicesProvider.overrideWith(
          (ref) => ref.watch(deviceRepositoryProvider).watchAll(),
        ),
        remoteSessionProvider.overrideWith(
          (ref) async =>
              FakeRemoteSession(pairingTarget: lounge.toDiscoveredTv()),
        ),
      ],
    );
  }

  for (final b in Brightness.values) {
    testWidgets('devices_screen_${b.name}', (t) async {
      await pump(t, location: AppRoutes.devices, brightness: b);
      await expectLater(
        find.byType(DevicesScreen),
        matchesGoldenFile('goldens/devices_screen_${b.name}.png'),
      );
    });
  }

  testWidgets('edit_device_dark', (t) async {
    await pump(
      t,
      location: AppRoutes.editDevice('Living Room TV 3'),
      brightness: Brightness.dark,
    );
    // Take the focus (and the caret) out of the picture.
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pumpAndSettle();
    await expectLater(
      find.byType(EditDeviceScreen),
      matchesGoldenFile('goldens/edit_device_dark.png'),
    );
  });
}
