@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/features/apps/presentation/manage_apps_screen.dart';

import '../../helpers/pump_router_app.dart';

void main() {
  for (final b in Brightness.values) {
    testWidgets('manage_apps_${b.name}', (t) async {
      t.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      // The "*" default row, as a new user has it.
      await pumpRouterApp(
        t,
        initialLocation: AppRoutes.manageApps,
        brightness: b,
      );
      await expectLater(
        find.byType(ManageAppsScreen),
        matchesGoldenFile('goldens/manage_apps_${b.name}.png'),
      );
    });
  }

  testWidgets('shortcut_editor_light', (t) async {
    t.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final semantics = t.ensureSemantics();
    await pumpRouterApp(t, initialLocation: AppRoutes.manageApps);
    await t.tap(find.byTooltip('Add app'));
    await t.pumpAndSettle();
    await t.tap(find.text('Create a custom shortcut'));
    await t.pumpAndSettle();
    await t.enterText(
      find.byKey(const ValueKey('shortcut_name')),
      'Family movies',
    );
    await t.enterText(
      find.byKey(const ValueKey('shortcut_package')),
      'com.example.movies',
    );
    await t.tap(find.bySemanticsLabel('Teal'));
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel('Sports'));
    await t.pumpAndSettle();
    // Take the focus (and the caret) out of the picture.
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/shortcut_editor_light.png'),
    );
    semantics.dispose();
  });
}
