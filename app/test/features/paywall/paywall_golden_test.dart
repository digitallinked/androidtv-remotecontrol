@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/purchases/purchase_service.dart';
import 'package:tv_remote/features/paywall/presentation/paywall_screen.dart';

import '../../helpers/fake_purchase_service.dart';
import '../../helpers/pump_router_app.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('paywall_${brightness.name}', (t) async {
      t.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await pumpRouterApp(
        t,
        initialLocation: '/paywall?source=settings',
        brightness: brightness,
        overrides: [
          purchaseServiceProvider.overrideWithValue(
            FakePurchaseService(offer: testOffer()),
          ),
        ],
      );
      await expectLater(
        find.byType(PaywallScreen),
        matchesGoldenFile('goldens/paywall_${brightness.name}.png'),
      );
    });
  }
}
