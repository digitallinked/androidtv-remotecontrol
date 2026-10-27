@Tags(['golden'])
library;

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/tv/saved_device_x.dart';
import 'package:tv_remote/features/apps/presentation/apps_screen.dart';

import '../../helpers/fake_remote_session.dart';
import '../../helpers/pump_router_app.dart';
import '../../helpers/test_devices.dart';

void main() {
  for (final b in Brightness.values) {
    testWidgets('apps_screen_${b.name}', (t) async {
      t.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      // Connected, with the "*" default row; YouTube is open on the TV.
      final fake = FakeRemoteSession(
        pairingTarget: savedTv().toDiscoveredTv(),
        initial: const TvConnectionState(status: ConnectionStatus.connected),
      )..push(const CurrentAppChanged('com.google.android.youtube.tv'));
      await pumpRouterApp(
        t,
        initialLocation: AppRoutes.apps,
        brightness: b,
        overrides: [remoteSessionProvider.overrideWith((ref) async => fake)],
      );
      await expectLater(
        find.byType(AppsScreen),
        matchesGoldenFile('goldens/apps_screen_${b.name}.png'),
      );
    });
  }
}
