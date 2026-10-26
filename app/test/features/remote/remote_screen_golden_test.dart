@Tags(['golden'])
library;

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/core/tv/saved_device_x.dart';
import 'package:tv_remote/features/remote/presentation/remote_screen.dart';

import '../../helpers/fake_remote_session.dart';
import '../../helpers/pump_router_app.dart';
import '../../helpers/test_devices.dart';

void main() {
  for (final b in Brightness.values) {
    testWidgets('remote_basic_${b.name}', (t) async {
      t.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final fake = FakeRemoteSession(
        pairingTarget: savedTv().toDiscoveredTv(),
        initial: const TvConnectionState(status: ConnectionStatus.connected),
      );
      await pumpRouterApp(
        t,
        initialLocation: AppRoutes.remote,
        brightness: b,
        overrides: [
          remoteSessionProvider.overrideWith((ref) async => fake),
          savedDevicesProvider.overrideWith(
            (ref) => Stream.value([savedTv()]),
          ),
        ],
      );
      await expectLater(
        find.byType(RemoteScreen),
        matchesGoldenFile('goldens/remote_basic_${b.name}.png'),
      );
    });
  }
}
