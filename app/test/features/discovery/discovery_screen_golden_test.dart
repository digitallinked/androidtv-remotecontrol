@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/discovery/data/discovery_providers.dart';

import '../../helpers/fake_tv_discovery.dart';
import '../../helpers/pump_router_app.dart';
import '../../helpers/test_devices.dart';

void main() {
  late FakeTvDiscoveries discoveries;

  setUp(() => discoveries = FakeTvDiscoveries());

  Future<void> pumpDiscover(WidgetTester t, Brightness brightness) async {
    t.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.discover,
      brightness: brightness,
      settle: false,
      overrides: [
        tvDiscoveryFactoryProvider.overrideWithValue(discoveries.create),
        savedDevicesProvider.overrideWith(
          (ref) => Stream.value([savedTv(name: 'Living Room TV')]),
        ),
      ],
    );
    await t.pump();
  }

  for (final b in Brightness.values) {
    testWidgets('discovery_found_${b.name}', (t) async {
      await pumpDiscover(t, b);
      discoveries.created.single.emit([
        tv('Living Room TV', host: '192.168.1.20'),
        tv('Bedroom', host: '192.168.1.31', legacy: true),
      ]);
      await t.pump();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/discovery_found_${b.name}.png'),
      );
    });

    testWidgets('discovery_troubleshooting_${b.name}', (t) async {
      await pumpDiscover(t, b);
      await t.pump(const Duration(seconds: 10));
      await t.pump();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/discovery_troubleshooting_${b.name}.png'),
      );
    });
  }
}
