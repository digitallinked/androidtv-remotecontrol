@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/features/onboarding/presentation/onboarding_screen.dart';

import '../../helpers/golden.dart';

void main() {
  Future<void> pumpOnboarding(WidgetTester t, Brightness brightness) =>
      pumpForGolden(
        t,
        const ProviderScope(child: OnboardingScreen()),
        brightness: brightness,
        size: const Size(360, 760),
      );

  testWidgets('onboarding_connect_light', (t) async {
    await pumpOnboarding(t, Brightness.light);
    await expectLater(
      find.byType(OnboardingScreen),
      matchesGoldenFile('goldens/onboarding_connect_light.png'),
    );
  });

  testWidgets('onboarding_connect_dark', (t) async {
    await pumpOnboarding(t, Brightness.dark);
    await expectLater(
      find.byType(OnboardingScreen),
      matchesGoldenFile('goldens/onboarding_connect_dark.png'),
    );
  });

  testWidgets('onboarding_apps_dark', (t) async {
    await pumpOnboarding(t, Brightness.dark);
    for (var i = 0; i < 2; i++) {
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
    }
    await expectLater(
      find.byType(OnboardingScreen),
      matchesGoldenFile('goldens/onboarding_apps_dark.png'),
    );
  });
}
