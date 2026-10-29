@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/purchases/premium.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/features/settings/presentation/appearance_page.dart';

import '../../helpers/pump_router_app.dart';
import '../../helpers/test_premium.dart';

void main() {
  testWidgets('appearance_styles_dark', (t) async {
    t.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    // A Premium user with Midnight chosen.
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.settingsAppearance,
      brightness: Brightness.dark,
      prepareSettings: (store) async {
        await store.setThemePreference(ThemePreference.dark);
        await store.setColourStyle(ColourStyle.midnight);
      },
      overrides: [
        premiumProvider.overrideWith(
          () => TestPremium(const PremiumState(isPremium: true, known: true)),
        ),
      ],
    );
    await expectLater(
      find.byType(AppearancePage),
      matchesGoldenFile('goldens/appearance_styles_dark.png'),
    );
  });
}
