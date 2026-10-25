@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';

import '../../helpers/pump_router_app.dart';

void main() {
  for (final b in Brightness.values) {
    testWidgets('discovery_empty_${b.name}', (t) async {
      t.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await pumpRouterApp(
        t,
        initialLocation: AppRoutes.discover,
        brightness: b,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/discovery_empty_${b.name}.png'),
      );
    });
  }
}
