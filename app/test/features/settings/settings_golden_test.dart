@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/features/settings/presentation/remote_layout_page.dart';
import 'package:tv_remote/features/settings/presentation/settings_screen.dart';

import '../../helpers/pump_router_app.dart';

void main() {
  Future<void> pumpAt(
    WidgetTester t,
    String location,
    Brightness brightness,
  ) async {
    t.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpRouterApp(
      t,
      initialLocation: location,
      brightness: brightness,
    );
  }

  for (final b in Brightness.values) {
    testWidgets('settings_hub_${b.name}', (t) async {
      await pumpAt(t, AppRoutes.settings, b);
      await expectLater(
        find.byType(SettingsScreen),
        matchesGoldenFile('goldens/settings_hub_${b.name}.png'),
      );
    });
  }

  testWidgets('remote_layout_page_light', (t) async {
    await pumpAt(t, AppRoutes.settingsRemoteLayout, Brightness.light);
    await expectLater(
      find.byType(RemoteLayoutPage),
      matchesGoldenFile('goldens/remote_layout_page_light.png'),
    );
  });
}
