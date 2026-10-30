@Tags(['golden'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/features/pairing/data/pairing_providers.dart';

import '../../helpers/fake_pairing_client.dart';
import '../../helpers/fake_tv_discovery.dart';
import '../../helpers/pump_router_app.dart';

void main() {
  for (final b in Brightness.values) {
    testWidgets('pairing_waiting_${b.name}', (t) async {
      t.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final fakes = FakePairingClients();
      await pumpRouterApp(
        t,
        initialLocation: AppRoutes.discover,
        brightness: b,
        settle: false,
        // The page appears without its transition, so the spinner (which
        // never settles and ignores reduce motion) is captured at the same
        // 400 ms as before pages animated.
        disableAnimations: true,
        overrides: [
          pairingClientFactoryProvider.overrideWithValue(fakes.create),
        ],
      );
      final tvToPair = tv('Living Room TV');
      final router = ProviderScope.containerOf(
        t.element(find.byType(MaterialApp)),
      ).read(appRouterProvider);
      unawaited(
        router.push(AppRoutes.pair(tvToPair.serviceName), extra: tvToPair),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/pairing_waiting_${b.name}.png'),
      );
    });
  }
}
