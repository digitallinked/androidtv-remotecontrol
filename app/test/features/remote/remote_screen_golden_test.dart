@Tags(['golden'])
library;

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/core/tv/saved_device_x.dart';
import 'package:tv_remote/features/remote/presentation/remote_screen.dart';

import '../../helpers/fake_remote_session.dart';
import '../../helpers/pump_router_app.dart';
import '../../helpers/test_devices.dart';

void main() {
  /// The connected remote at [size], with the volume the TV reported.
  Future<void> pumpRemote(
    WidgetTester t, {
    required Size size,
    required Brightness brightness,
    NavigationStyle nav = NavigationStyle.touchpad,
  }) async {
    t.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final fake = FakeRemoteSession(
      pairingTarget: savedTv().toDiscoveredTv(),
      initial: const TvConnectionState(status: ConnectionStatus.connected),
    )..push(const VolumeChanged(12, 100, false));
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.remote,
      brightness: brightness,
      prepareSettings: (store) => store.setNavigationStyle(nav),
      overrides: [
        remoteSessionProvider.overrideWith((ref) async => fake),
        savedDevicesProvider.overrideWith(
          (ref) => Stream.value([savedTv()]),
        ),
      ],
    );
  }

  for (final b in Brightness.values) {
    testWidgets('remote_portrait_${b.name}', (t) async {
      await pumpRemote(t, size: const Size(390, 844), brightness: b);
      await expectLater(
        find.byType(RemoteScreen),
        matchesGoldenFile('goldens/remote_portrait_${b.name}.png'),
      );
    });
  }

  testWidgets('remote_landscape', (t) async {
    await pumpRemote(
      t,
      size: const Size(844, 390),
      brightness: Brightness.dark,
      nav: NavigationStyle.dpad,
    );
    await expectLater(
      find.byType(RemoteScreen),
      matchesGoldenFile('goldens/remote_landscape.png'),
    );
  });

  testWidgets('remote_tablet', (t) async {
    await pumpRemote(
      t,
      size: const Size(834, 1194),
      brightness: Brightness.light,
    );
    await expectLater(
      find.byType(RemoteScreen),
      matchesGoldenFile('goldens/remote_tablet.png'),
    );
  });
}
