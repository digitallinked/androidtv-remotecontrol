@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/ads/consent_service.dart';
import 'package:tv_remote/features/settings/presentation/privacy_choices_page.dart';

import '../../helpers/fake_consent_service.dart';
import '../../helpers/pump_router_app.dart';

void main() {
  testWidgets('privacy_choices_light', (t) async {
    t.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    // A free user (the fake region is "consent not required"), with the Ad
    // privacy choices row on, so every kind of row can show.
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.settingsPrivacy,
      overrides: [
        consentServiceProvider.overrideWithValue(
          FakeConsentService(optionsRequired: true),
        ),
      ],
    );
    await expectLater(
      find.byType(PrivacyChoicesPage),
      matchesGoldenFile('goldens/privacy_choices_light.png'),
    );
  });
}
