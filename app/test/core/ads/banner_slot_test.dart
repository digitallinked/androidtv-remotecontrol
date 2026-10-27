import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tv_remote/app/flavor.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/ads/ad_unit_ids.dart';
import 'package:tv_remote/core/ads/ads_service.dart';
import 'package:tv_remote/core/ads/banner_slot.dart';
import 'package:tv_remote/core/ads/consent_service.dart';
import 'package:tv_remote/core/ads/tracking_service.dart';
import 'package:tv_remote/core/config/app_config.dart';
import 'package:tv_remote/core/config/service_config.dart';
import 'package:tv_remote/core/purchases/premium.dart';
import 'package:tv_remote/features/paywall/domain/paywall_source.dart';

import '../../helpers/fake_ads_sdk.dart';
import '../../helpers/fake_consent_service.dart';
import '../../helpers/fake_tracking_service.dart';
import '../../helpers/nonlinear_text_scaler.dart';
import '../../helpers/platform_override.dart';
import '../../helpers/pump_router_app.dart';
import '../../helpers/test_app_config.dart';
import '../../helpers/test_premium.dart';

final Finder _banner = find.byKey(const ValueKey('fake_banner'));

Finder _slot(AdPlacement placement) =>
    find.byKey(ValueKey('banner_slot_${placement.name}'));

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  Future<void> pumpAt(
    WidgetTester t,
    String location, {
    required FakeAdsSdk sdk,
    List<Override> overrides = const [],
    Size size = const Size(390, 844),
    double textScale = 1,
    TextScaler? textScaler,
    Brightness brightness = Brightness.light,
  }) async {
    t.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpRouterApp(
      t,
      initialLocation: location,
      overrides: [adsSdkProvider.overrideWithValue(sdk), ...overrides],
      textScale: textScale,
      textScaler: textScaler,
      brightness: brightness,
    );
  }

  group('without a loaded ad', () {
    testWidgets('banner_slot_takes_no_space_until_an_ad_loads', (t) async {
      // The default fake starts the SDK and asks for a banner, but never
      // loads one: the slot stays empty, as in Phase 5.
      final sdk = FakeAdsSdk();
      for (final (location, placement) in [
        (AppRoutes.apps, AdPlacement.apps),
        (AppRoutes.settings, AdPlacement.settings),
      ]) {
        await pumpAt(t, location, sdk: sdk);
        expect(_slot(placement), findsOneWidget);
        expect(_banner, findsNothing);
        expect(t.getSize(_slot(placement)).height, 0);
        expect(t.getSize(find.byType(BannerSlot)).height, 0);
      }
      expect(sdk.initializeCalls, greaterThan(0));
      expect(sdk.bannerLoads, greaterThan(0));
      expect(AdPlacement.values.map((p) => p.name), ['apps', 'settings']);
    });

    test('banner_slot_clearance_is_48dp', () {
      expect(BannerSlot.clearance, 48);
    });
  });

  testWidgets('no_banner_on_remote_screen', (t) async {
    // Every route except the Apps screen and the Settings hub.
    for (final location in [
      AppRoutes.remote,
      AppRoutes.discover,
      AppRoutes.onboarding,
      AppRoutes.manageApps,
      AppRoutes.devices,
      AppRoutes.paywall(source: PaywallSource.settings),
    ]) {
      final sdk = FakeAdsSdk(loads: true);
      await pumpAt(t, location, sdk: sdk);
      expect(find.byType(BannerSlot), findsNothing, reason: location);
      expect(_banner, findsNothing, reason: location);
      expect(sdk.bannerLoads, 0, reason: location);
      expect(sdk.initializeCalls, 0, reason: location);
    }
    // A Settings sub-page sits on top of the hub, which stays built but off
    // stage: nothing visible, no banner on the page itself.
    for (final location in [
      AppRoutes.settingsAppearance,
      AppRoutes.settingsRemoteLayout,
      AppRoutes.settingsRemoteBehaviour,
      AppRoutes.settingsHelp,
      AppRoutes.settingsAbout,
      AppRoutes.settingsPrivacy,
    ]) {
      await pumpAt(t, location, sdk: FakeAdsSdk(loads: true));
      expect(find.byType(BannerSlot), findsNothing, reason: location);
      expect(_banner, findsNothing, reason: location);
    }
  });

  testWidgets('banner_shows_on_apps_and_settings_when_allowed', (t) async {
    final handle = t.ensureSemantics();
    for (final (location, placement) in [
      (AppRoutes.apps, AdPlacement.apps),
      (AppRoutes.settings, AdPlacement.settings),
    ]) {
      final sdk = FakeAdsSdk(loads: true);
      await pumpAt(t, location, sdk: sdk);
      expect(_banner, findsOneWidget, reason: location);
      expect(find.text('Advertisement'), findsOneWidget);
      expect(find.bySemanticsLabel('Advertisement'), findsOneWidget);
      expect(_slot(placement), findsOneWidget);
      expect(sdk.initializeCalls, 1);
      // The test unit of this platform (dev always uses Google's).
      expect(sdk.bannerUnits, [AdMobTestIds.androidBanner]);
      // The label band is at least 48 dp tall, and the creative sits below
      // it at the width of the screen.
      final slot = t.getRect(_slot(placement));
      final ad = t.getRect(_banner);
      expect(ad.width, 390);
      expect(ad.bottom, slot.bottom);
      // A 1 dp divider, then the band, then the creative.
      expect(ad.top - slot.top - 1, greaterThanOrEqualTo(48));
      final label = t.getRect(find.text('Advertisement'));
      expect(label.top, greaterThanOrEqualTo(slot.top + 1));
      expect(label.bottom, lessThanOrEqualTo(ad.top));
    }
    handle.dispose();
  });

  testWidgets('banner_hidden_for_premium', (t) async {
    final sdk = FakeAdsSdk(loads: true);
    await pumpAt(
      t,
      AppRoutes.settings,
      sdk: sdk,
      overrides: [
        premiumProvider.overrideWith(
          () => TestPremium(
            const PremiumState(isPremium: true, known: true, lifetime: true),
          ),
        ),
      ],
    );
    expect(_banner, findsNothing);
    expect(t.getSize(_slot(AdPlacement.settings)).height, 0);
    expect(sdk.bannerLoads, 0);
    expect(sdk.initializeCalls, 0);
  });

  testWidgets('premium_stream_drives_ads_off', (t) async {
    final premium = TestPremium(PremiumState.free);
    final sdk = FakeAdsSdk(loads: true);
    await pumpAt(
      t,
      AppRoutes.settings,
      sdk: sdk,
      overrides: [premiumProvider.overrideWith(() => premium)],
    );
    expect(_banner, findsOneWidget);
    expect(sdk.disposed, 0);

    premium.set(const PremiumState(isPremium: true, known: true));
    await t.pumpAndSettle();

    expect(_banner, findsNothing);
    expect(t.getSize(_slot(AdPlacement.settings)).height, 0);
    expect(sdk.disposed, 1);

    // Losing Premium brings the ad back with a fresh load.
    premium.set(PremiumState.free);
    await t.pumpAndSettle();
    expect(_banner, findsOneWidget);
    expect(sdk.bannerLoads, 2);
  });

  testWidgets('banner_waits_for_premium_to_be_known', (t) async {
    final premium = TestPremium(
      const PremiumState(isPremium: false, known: false),
    );
    final sdk = FakeAdsSdk(loads: true);
    await pumpAt(
      t,
      AppRoutes.settings,
      sdk: sdk,
      overrides: [premiumProvider.overrideWith(() => premium)],
    );
    expect(_banner, findsNothing);
    expect(sdk.bannerLoads, 0);
    expect(sdk.initializeCalls, 0);

    premium.set(PremiumState.free);
    await t.pumpAndSettle();
    expect(_banner, findsOneWidget);
    expect(sdk.bannerLoads, 1);
  });

  testWidgets('banner_respects_the_kill_switch', (t) async {
    final sdk = FakeAdsSdk(loads: true);
    await pumpAt(
      t,
      AppRoutes.settings,
      sdk: sdk,
      overrides: [
        appConfigProvider.overrideWith(
          () => TestAppConfig(const {'ads_banner_enabled': false}),
        ),
      ],
    );
    expect(_banner, findsNothing);
    expect(t.getSize(_slot(AdPlacement.settings)).height, 0);
    expect(sdk.bannerLoads, 0);
  });

  testWidgets('no_banner_when_consent_denies_ad_requests', (t) async {
    final sdk = FakeAdsSdk(loads: true);
    await pumpAt(
      t,
      AppRoutes.apps,
      sdk: sdk,
      overrides: [
        consentServiceProvider.overrideWithValue(
          FakeConsentService(canRequest: false),
        ),
      ],
    );
    expect(_banner, findsNothing);
    expect(sdk.initializeCalls, 0);
    expect(sdk.bannerLoads, 0);
  });

  testWidgetsOn(
    TargetPlatform.iOS,
    'ios_waits_for_the_tracking_decision_before_the_first_ad',
    (t) async {
      final tracking = FakeTrackingService(
        current: TrackingStatus.notDetermined,
      );
      final sdk = FakeAdsSdk(loads: true);
      await pumpAt(
        t,
        AppRoutes.settings,
        sdk: sdk,
        overrides: [trackingServiceProvider.overrideWithValue(tracking)],
      );

      // The pre-prompt is on screen; no ad has been asked for yet.
      expect(find.text('About ads in this app'), findsOneWidget);
      expect(sdk.bannerLoads, 0);
      expect(_banner, findsNothing);
      expect(tracking.requests, 0);

      await t.tap(find.text('Continue'));
      await t.pumpAndSettle();

      expect(tracking.requests, 1);
      expect(sdk.bannerUnits, [AdMobTestIds.iosBanner]);
      expect(_banner, findsOneWidget);
    },
  );

  testWidgets('prod_without_unit_ids_shows_no_banner', (t) async {
    final sdk = FakeAdsSdk(loads: true);
    await pumpAt(
      t,
      AppRoutes.settings,
      sdk: sdk,
      overrides: [flavorProvider.overrideWithValue(Flavor.prod)],
    );
    expect(_banner, findsNothing);
    expect(t.getSize(_slot(AdPlacement.settings)).height, 0);
    expect(sdk.bannerLoads, 0);
    expect(sdk.initializeCalls, 0);

    // With the define set, prod loads that unit and not a test one.
    final withId = FakeAdsSdk(loads: true);
    await pumpAt(
      t,
      AppRoutes.settings,
      sdk: withId,
      overrides: [
        flavorProvider.overrideWithValue(Flavor.prod),
        serviceConfigProvider.overrideWithValue(
          const ServiceConfig(admobBannerAndroid: 'prod-banner-android'),
        ),
      ],
    );
    expect(_banner, findsOneWidget);
    expect(withId.bannerUnits, ['prod-banner-android']);
  });

  testWidgets('failed_load_takes_no_space', (t) async {
    final sdk = FakeAdsSdk(loads: true, failLoads: true);
    await pumpAt(t, AppRoutes.settings, sdk: sdk);
    expect(_banner, findsNothing);
    expect(t.getSize(_slot(AdPlacement.settings)).height, 0);
    expect(sdk.bannerLoads, 1);

    // Not retried while the visit lasts, however often the page rebuilds.
    await t.pump(const Duration(seconds: 30));
    await t.pumpAndSettle();
    expect(sdk.bannerLoads, 1);
  });

  testWidgets('banner_disposed_when_leaving_and_reloaded_on_rotation', (
    t,
  ) async {
    final sdk = FakeAdsSdk(loads: true);
    await pumpAt(t, AppRoutes.settings, sdk: sdk);
    expect(_banner, findsOneWidget);
    expect(sdk.bannerLoads, 1);
    expect(sdk.disposed, 0);

    // Rotating loads a banner for the new width and disposes the old one.
    t.view.physicalSize = const Size(844, 390);
    await t.pumpAndSettle();
    expect(sdk.disposed, 1);
    expect(sdk.bannerLoads, 2);
    expect(_banner, findsOneWidget);
    expect(t.getSize(_banner).width, 844);

    // Leaving the screen disposes the ad.
    GoRouter.of(t.element(find.byType(Scaffold).first)).go(AppRoutes.devices);
    await t.pumpAndSettle();
    expect(_banner, findsNothing);
    expect(sdk.disposed, 2);
  });

  testWidgets('tiny_screens_skip_the_banner', (t) async {
    final sdk = FakeAdsSdk(loads: true);
    await pumpAt(
      t,
      AppRoutes.settings,
      sdk: sdk,
      size: const Size(640, 300),
      textScale: 2,
    );
    expect(_banner, findsNothing);
    expect(t.getSize(_slot(AdPlacement.settings)).height, 0);
    expect(sdk.bannerLoads, 0);
  });

  group('loaded_banner_fits_320dp_at_200_percent_text', () {
    final scalers = <String, (double, TextScaler?)>{
      'linear': (2, null),
      'nonlinear': (1, const NonlinearTwoXScaler()),
    };
    for (final MapEntry(key: name, value: (scale, scaler)) in scalers.entries) {
      for (final brightness in Brightness.values) {
        for (final location in [AppRoutes.apps, AppRoutes.settings]) {
          testWidgets('${name}_${brightness.name}_$location', (t) async {
            final sdk = FakeAdsSdk(loads: true);
            await pumpAt(
              t,
              location,
              sdk: sdk,
              size: const Size(320, 640),
              textScale: scale,
              textScaler: scaler,
              brightness: brightness,
            );
            expect(t.takeException(), isNull);
            expect(_banner, findsOneWidget);

            final ad = t.getRect(_banner);
            final label = t.getRect(find.text('Advertisement'));
            expect(ad.width, 320);
            expect(ad.right, lessThanOrEqualTo(320));
            // The caption is whole, inside the screen and above the creative
            // with at least the 48 dp band around it.
            expect(label.left, greaterThanOrEqualTo(0));
            expect(label.right, lessThanOrEqualTo(320));
            expect(label.bottom, lessThanOrEqualTo(ad.top));
            expect(ad.top - label.top, greaterThanOrEqualTo(24));
          });
        }
      }
    }
  });
}
