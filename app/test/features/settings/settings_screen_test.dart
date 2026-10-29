import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/ads/ads_service.dart';
import 'package:tv_remote/core/ads/interstitials.dart';
import 'package:tv_remote/core/config/app_config.dart';
import 'package:tv_remote/core/purchases/premium.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/features/discovery/data/discovery_providers.dart';
import 'package:tv_remote/features/discovery/presentation/discovery_screen.dart';
import 'package:tv_remote/features/settings/presentation/settings_screen.dart';

import '../../helpers/fake_ads_sdk.dart';
import '../../helpers/fake_remote_session.dart';
import '../../helpers/fake_tv_discovery.dart';
import '../../helpers/gather_consent.dart';
import '../../helpers/pump_router_app.dart';
import '../../helpers/test_app_config.dart';
import '../../helpers/test_premium.dart';

void main() {
  /// Pumps the hub on a phone-sized view.
  Future<void> pumpHub(
    WidgetTester t, {
    Size size = const Size(390, 844),
    double textScale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    t.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.settings,
      textScale: textScale,
      brightness: brightness,
    );
  }

  Finder appBarTitle(String title) =>
      find.descendant(of: find.byType(AppBar), matching: find.text(title));

  /// Scrolls to the top, then down until [target] is on screen.
  Future<void> reveal(WidgetTester t, Finder target) async {
    await t.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      target,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(target);
    await t.pumpAndSettle();
  }

  testWidgets('hub_lists_every_section_and_opens_its_page', (t) async {
    await pumpHub(t);

    for (final header in const [
      'Remote',
      'App',
      'Help and feedback',
      'About',
    ]) {
      await reveal(t, find.text(header));
      expect(find.text(header), findsOneWidget, reason: header);
    }

    const rows = [
      ('Remote layout', 'Remote layout'),
      ('Remote behaviour', 'Remote behaviour'),
      ('Apps', 'Edit apps'),
      ('Your TVs', 'Your TVs'),
      ('Appearance', 'Appearance'),
      ('Help', 'Help'),
      ('About this app', 'About this app'),
    ];
    for (final (row, title) in rows) {
      await reveal(t, find.text(row));
      await t.tap(find.text(row));
      await t.pumpAndSettle();
      expect(appBarTitle(title), findsOneWidget, reason: row);

      await t.pageBack();
      await t.pumpAndSettle();
      expect(appBarTitle('Settings'), findsOneWidget, reason: '$row back');
    }
  });

  testWidgets('hub_has_one_banner_slot_and_no_fab', (t) async {
    await pumpHub(t);

    expect(find.byKey(const ValueKey('banner_slot_settings')), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('hub_scroll_ends_with_banner_clearance', (t) async {
    await pumpHub(t, size: const Size(390, 500));
    await reveal(t, find.text('Terms of use'));
    await t.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await t.pumpAndSettle();

    final terms = t.getRect(find.text('Terms of use'));
    final bottom = t.getRect(find.byType(Scaffold).first).bottom;
    expect(bottom - terms.bottom, greaterThanOrEqualTo(48));
  });

  testWidgets('external_rows_say_they_open_the_browser', (t) async {
    final handle = t.ensureSemantics();
    await pumpHub(t);

    for (final title in const ['Privacy policy', 'Terms of use']) {
      await reveal(t, find.text(title));
      expect(
        t.getSemantics(find.text(title)).hint,
        contains('Opens in your browser'),
        reason: title,
      );
    }
    expect(
      t.getSemantics(find.text('About this app')).hint,
      isNot(contains('Opens in your browser')),
    );
    handle.dispose();
  });

  testWidgets(
    'leaving_a_hub_opened_before_pairing_never_shows_an_interstitial',
    (t) async {
      // Every interstitial rule holds: Remote Config on, the second launch, a
      // known free user, consent that allows ads and one ad loaded.
      final sdk = FakeAdsSdk(loads: true);
      await pumpRouterApp(
        t,
        initialLocation: AppRoutes.remote,
        prepareSettings: (store) => store.setLaunchCount(2),
        overrides: [
          adsSdkProvider.overrideWithValue(sdk),
          appConfigProvider.overrideWith(
            () => TestAppConfig(const {'ads_interstitial_enabled': true}),
          ),
          premiumProvider.overrideWith(() => TestPremium(PremiumState.free)),
          remoteSessionProvider.overrideWith(
            (ref) async => FakeRemoteSession(
              initial: const TvConnectionState(
                status: ConnectionStatus.connected,
              ),
            ),
          ),
        ],
      );
      // `App` keeps the pacing listened to from launch.
      final container = ProviderScope.containerOf(
        t.element(find.byType(MaterialApp)),
      )..listen(interstitialsProvider, (_, _) {});
      await gatherConsent(t);
      expect(sdk.interstitialLoads, 1, reason: 'one ad is kept loaded');
      final router = container.read(appRouterProvider);

      // The hub as discovery and the no-TV remote open it.
      unawaited(router.push<void>(AppRoutes.settingsFromSetup));
      await t.pumpAndSettle();
      expect(
        t.widget<SettingsScreen>(find.byType(SettingsScreen)).fromSetup,
        isTrue,
      );
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsNothing);
      expect(sdk.shows, 0);

      // The control: the same app, the hub opened from the remote.
      unawaited(router.push<void>(AppRoutes.settings));
      await t.pumpAndSettle();
      expect(
        t.widget<SettingsScreen>(find.byType(SettingsScreen)).fromSetup,
        isFalse,
      );
      await t.pageBack();
      await t.pumpAndSettle();
      expect(sdk.shows, 1);
    },
  );

  testWidgets('help_privacy_and_feedback_are_reachable_before_pairing', (
    t,
  ) async {
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.discover,
      settle: false,
      overrides: [
        tvDiscoveryFactoryProvider.overrideWithValue(
          FakeTvDiscoveries().create,
        ),
      ],
    );
    await t.pump();
    await t.tap(find.byTooltip('Settings'));
    await t.pumpAndSettle();
    expect(appBarTitle('Settings'), findsOneWidget);

    await reveal(t, find.text('Help'));
    await t.tap(find.text('Help'));
    await t.pumpAndSettle();
    expect(appBarTitle('Help'), findsOneWidget);
    expect(find.text('Common questions'), findsOneWidget);
    await t.scrollUntilVisible(
      find.text('Send feedback'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Send feedback'), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();

    await reveal(t, find.text('Privacy choices'));
    await t.tap(find.text('Privacy choices'));
    await t.pumpAndSettle();
    expect(appBarTitle('Privacy choices'), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    expect(appBarTitle('Settings'), findsOneWidget);

    // Back again: discovery, where the search is still running.
    await t.pageBack();
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.byType(DiscoveryScreen), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
    expect(t.takeException(), isNull);
  });

  for (final b in Brightness.values) {
    testWidgets('settings_hub_fits_320dp_at_200_percent_text_${b.name}', (
      t,
    ) async {
      await pumpHub(
        t,
        size: const Size(320, 640),
        textScale: 2,
        brightness: b,
      );

      for (var i = 0; i < 14; i++) {
        await t.drag(find.byType(Scrollable).first, const Offset(0, -300));
        await t.pump();
      }
      await t.pumpAndSettle();

      expect(t.takeException(), isNull);
      expect(find.text('Terms of use'), findsOneWidget);
    });
  }
}
