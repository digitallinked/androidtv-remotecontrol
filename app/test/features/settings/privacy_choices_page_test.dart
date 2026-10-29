import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/app_links.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/ads/banner_slot.dart';
import 'package:tv_remote/core/ads/consent_service.dart';
import 'package:tv_remote/core/ads/tracking_service.dart';
import 'package:tv_remote/core/firebase/firebase_bootstrap.dart';
import 'package:tv_remote/core/links/link_opener.dart';
import 'package:tv_remote/core/privacy/privacy_choices.dart';
import 'package:tv_remote/core/purchases/premium.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/features/paywall/domain/paywall_source.dart';
import 'package:tv_remote/features/paywall/presentation/paywall_screen.dart';
import 'package:tv_remote/features/settings/presentation/privacy_choices_page.dart';

import '../../helpers/fake_consent_service.dart';
import '../../helpers/fake_tracking_service.dart';
import '../../helpers/nonlinear_text_scaler.dart';
import '../../helpers/platform_override.dart';
import '../../helpers/pump_router_app.dart';
import '../../helpers/recording_link_opener.dart';
import '../../helpers/test_premium.dart';

const _servicesOff =
    "This build of the app doesn't send usage statistics or crash reports.";
const _adChoicesFailed = "Couldn't open ad privacy choices";

void main() {
  late FakeConsentService consent;
  late RecordingLinkOpener links;

  setUp(() {
    consent = FakeConsentService();
    links = RecordingLinkOpener();
  });

  Future<SettingsStore> pumpPage(
    WidgetTester t, {
    ConsentRegion region = ConsentRegion.notRequired,
    bool? usageChoice,
    bool premium = false,
    FirebaseStatus firebase = FirebaseStatus.ready,
    TrackingService? tracking,
    Size size = const Size(390, 844),
    double textScale = 1,
    TextScaler? textScaler,
    Brightness brightness = Brightness.light,
  }) {
    t.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    // The platform's answer: the silent update writes it over the stored one.
    consent.region = region;
    return pumpRouterApp(
      t,
      initialLocation: AppRoutes.settingsPrivacy,
      textScale: textScale,
      textScaler: textScaler,
      brightness: brightness,
      prepareSettings: (store) async {
        await store.setConsentRegion(region);
        await store.setShareUsageStats(usageChoice);
      },
      overrides: [
        consentServiceProvider.overrideWithValue(consent),
        linkOpenerProvider.overrideWithValue(links),
        firebaseStatusProvider.overrideWithValue(firebase),
        premiumProvider.overrideWith(
          () => TestPremium(
            premium
                ? const PremiumState(isPremium: true, known: true)
                : PremiumState.free,
          ),
        ),
        if (tracking != null)
          trackingServiceProvider.overrideWithValue(tracking),
      ],
    );
  }

  ProviderContainer containerOf(WidgetTester t) =>
      ProviderScope.containerOf(t.element(find.byType(PrivacyChoicesPage)));

  bool switchValue(WidgetTester t, String title) => t
      .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, title))
      .value;

  Future<void> scrollTo(WidgetTester t, Finder f) async {
    await t.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable));
    await t.pumpAndSettle();
  }

  testWidgets('privacy_switches_show_the_effective_choice', (t) async {
    await pumpPage(t);
    expect(switchValue(t, 'Share usage statistics'), isTrue);
    expect(switchValue(t, 'Share crash reports'), isTrue);

    await pumpPage(t, region: ConsentRegion.required);
    expect(switchValue(t, 'Share usage statistics'), isFalse);
    expect(switchValue(t, 'Share crash reports'), isFalse);

    // Before the region is known nothing is shared either.
    await pumpPage(t, region: ConsentRegion.unknown);
    expect(switchValue(t, 'Share usage statistics'), isFalse);
    expect(switchValue(t, 'Share crash reports'), isFalse);
  });

  testWidgets('an_explicit_choice_wins_over_the_region', (t) async {
    await pumpPage(t, region: ConsentRegion.required, usageChoice: true);
    expect(switchValue(t, 'Share usage statistics'), isTrue);
    expect(switchValue(t, 'Share crash reports'), isFalse);
  });

  testWidgets('turning_usage_off_stores_an_explicit_choice', (t) async {
    final store = await pumpPage(t);
    expect(store.shareUsageStats, isNull);

    await t.tap(find.widgetWithText(SwitchListTile, 'Share usage statistics'));
    await t.pumpAndSettle();

    expect(store.shareUsageStats, isFalse);
    expect(store.shareCrashReports, isNull);
    expect(switchValue(t, 'Share usage statistics'), isFalse);
    final choices = containerOf(t).read(privacyChoicesProvider);
    expect(choices.shareUsage, isFalse);
    expect(choices.shareCrashReports, isTrue);
  });

  testWidgets('turning_crash_reports_off_stores_an_explicit_choice', (t) async {
    final store = await pumpPage(t);
    await t.tap(find.widgetWithText(SwitchListTile, 'Share crash reports'));
    await t.pumpAndSettle();
    expect(store.shareCrashReports, isFalse);
    expect(store.shareUsageStats, isNull);
    final choices = containerOf(t).read(privacyChoicesProvider);
    expect(choices.shareCrashReports, isFalse);
    expect(choices.shareUsage, isTrue);
  });

  testWidgets('ad_privacy_row_only_when_required', (t) async {
    await pumpPage(t);
    expect(find.text('Ad privacy choices'), findsNothing);

    consent.optionsRequired = true;
    await pumpPage(t);
    expect(find.text('Ad privacy choices'), findsOneWidget);
    expect(find.text('Choose how ads are picked for you.'), findsOneWidget);

    await t.tap(find.text('Ad privacy choices'));
    await t.pumpAndSettle();
    expect(consent.privacyOptionsCalls, 1);
    expect(find.textContaining(_adChoicesFailed), findsNothing);

    consent.optionsResult = false;
    await t.tap(find.text('Ad privacy choices'));
    await t.pumpAndSettle();
    expect(consent.privacyOptionsCalls, 2);
    expect(find.textContaining(_adChoicesFailed), findsOneWidget);
  });

  testWidgets('premium_users_see_no_ad_rows', (t) async {
    consent.optionsRequired = true;
    await pumpPage(t, premium: true);
    expect(
      find.text('You have Premium, so the app shows no ads.'),
      findsOneWidget,
    );
    expect(find.text('Remove ads with Premium'), findsNothing);
    expect(find.textContaining('shows a banner ad'), findsNothing);
  });

  testWidgets('premium_users_can_still_open_ad_privacy_choices', (t) async {
    // UMP's rules: when it says the entry point is required, it stays
    // reachable, Premium or not.
    consent.optionsRequired = true;
    await pumpPage(t, premium: true);
    expect(find.text('Ad privacy choices'), findsOneWidget);

    await t.tap(find.text('Ad privacy choices'));
    await t.pumpAndSettle();
    expect(consent.privacyOptionsCalls, 1);
  });

  testWidgets('free_users_see_the_ad_note_and_the_premium_row', (t) async {
    await pumpPage(t);
    expect(find.text('Ads'), findsOneWidget);
    expect(find.textContaining('shows a banner ad'), findsOneWidget);
    expect(find.text('Remove ads with Premium'), findsOneWidget);
  });

  testWidgets('remove_ads_opens_the_paywall_from_privacy', (t) async {
    await pumpPage(t);
    await t.tap(find.text('Remove ads with Premium'));
    await t.pumpAndSettle();
    final paywall = t.widget<PaywallScreen>(find.byType(PaywallScreen));
    expect(paywall.source, PaywallSource.privacy);
  });

  testWidgetsOn(
    TargetPlatform.iOS,
    'ios_tracking_row_shows_the_status_and_opens_settings',
    (
      t,
    ) async {
      await pumpPage(
        t,
        tracking: FakeTrackingService(current: TrackingStatus.denied),
      );
      await scrollTo(t, find.text('Ad tracking'));
      expect(
        find.text(
          "Not allowed. You can change this in your iPhone's Settings.",
        ),
        findsOneWidget,
      );

      await t.tap(find.text('Ad tracking'));
      await t.pumpAndSettle();
      expect(links.opened.map((u) => u.toString()), ['app-settings:']);
    },
  );

  testWidgetsOn(
    TargetPlatform.iOS,
    'ios_tracking_row_says_what_each_status_means',
    (t) async {
      const expected = {
        TrackingStatus.authorized:
            "Allowed. You can change this in your iPhone's Settings.",
        TrackingStatus.notDetermined:
            'Not chosen yet. The app asks before it first shows an ad.',
        TrackingStatus.restricted: 'Turned off on this iPhone.',
      };
      for (final entry in expected.entries) {
        await pumpPage(t, tracking: FakeTrackingService(current: entry.key));
        await scrollTo(t, find.text('Ad tracking'));
        expect(find.text(entry.value), findsOneWidget, reason: '${entry.key}');
      }
    },
  );

  testWidgetsOn(
    TargetPlatform.iOS,
    'ios_tracking_row_updates_when_the_app_returns',
    (t) async {
      final tracking = FakeTrackingService(current: TrackingStatus.denied);
      await pumpPage(t, tracking: tracking);
      await scrollTo(t, find.text('Ad tracking'));
      expect(find.textContaining('Not allowed'), findsOneWidget);

      // The user turned it on in the phone's Settings and came back.
      tracking.current = TrackingStatus.authorized;
      [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ].forEach(t.binding.handleAppLifecycleStateChanged);
      await t.pumpAndSettle();

      expect(find.textContaining('Allowed.'), findsOneWidget);
      expect(find.textContaining('Not allowed'), findsNothing);
    },
  );

  testWidgets('android_has_no_tracking_row', (t) async {
    await pumpPage(
      t,
      tracking: FakeTrackingService(current: TrackingStatus.denied),
    );
    expect(find.text('Ad tracking'), findsNothing);
  });

  testWidgets('the_privacy_policy_row_opens_the_policy', (t) async {
    await pumpPage(t);
    await scrollTo(t, find.text('Privacy policy'));
    await t.tap(find.text('Privacy policy'));
    await t.pumpAndSettle();
    expect(links.opened, [AppLinks.privacyPolicy]);
  });

  testWidgets('services_off_note_when_firebase_is_off', (t) async {
    await pumpPage(t, firebase: FirebaseStatus.notConfigured);
    expect(find.text(_servicesOff), findsOneWidget);

    await pumpPage(t, firebase: FirebaseStatus.unavailable);
    expect(find.text(_servicesOff), findsOneWidget);

    await pumpPage(t);
    expect(find.text(_servicesOff), findsNothing);
  });

  testWidgets('the_page_lists_its_parts_in_order', (t) async {
    consent.optionsRequired = true;
    await pumpPage(
      t,
      firebase: FirebaseStatus.notConfigured,
      size: const Size(390, 1600),
    );
    double y(String text) => t.getTopLeft(find.textContaining(text)).dy;
    final order = [
      y('Choose what the app may share'),
      y('Help improve the app'),
      y('Share usage statistics'),
      y('Share crash reports'),
      y(_servicesOff),
      y('shows a banner ad'),
      y('Remove ads with Premium'),
      y('Ad privacy choices'),
    ];
    expect(order, orderedEquals([...order]..sort()));
  });

  testWidgetsOn(
    TargetPlatform.iOS,
    'privacy_page_has_no_banner_and_fits_320dp_at_200_percent_text',
    (t) async {
      consent.optionsRequired = true;
      // The linear 200% and Android 14's non-linear curve, light and dark.
      for (final scaler in [
        const TextScaler.linear(2),
        const NonlinearTwoXScaler(),
      ]) {
        for (final b in Brightness.values) {
          final reason = '$scaler ${b.name}';
          await pumpPage(
            t,
            size: const Size(320, 640),
            textScaler: scaler,
            brightness: b,
            firebase: FirebaseStatus.notConfigured,
            tracking: FakeTrackingService(current: TrackingStatus.denied),
          );
          expect(find.byType(BannerSlot), findsNothing, reason: reason);

          // Every row that carries meaning is whole on screen: inside the
          // view, below the app bar, and with its texts inside the row.
          final appBar = t.getRect(find.byType(AppBar));
          for (final label in [
            'Remove ads with Premium',
            'Ad privacy choices',
            'Ad tracking',
            'Privacy policy',
          ]) {
            final row = find.ancestor(
              of: find.text(label),
              matching: find.byType(ListTile),
            );
            await t.scrollUntilVisible(
              row,
              100,
              scrollable: find.byType(Scrollable),
            );
            await t.ensureVisible(row);
            await t.pumpAndSettle();
            final rect = t.getRect(row);
            expect(
              rect.left,
              greaterThanOrEqualTo(0),
              reason: '$label $reason',
            );
            expect(
              rect.right,
              lessThanOrEqualTo(320),
              reason: '$label $reason',
            );
            expect(
              rect.top,
              greaterThanOrEqualTo(appBar.bottom),
              reason: '$label $reason',
            );
            expect(
              rect.bottom,
              lessThanOrEqualTo(640),
              reason: '$label $reason',
            );
            final texts = find.descendant(of: row, matching: find.byType(Text));
            for (final text in texts.evaluate()) {
              final inner = t.getRect(find.byWidget(text.widget));
              expect(
                inner.left,
                greaterThanOrEqualTo(rect.left),
                reason: '$label $reason',
              );
              expect(
                inner.right,
                lessThanOrEqualTo(rect.right),
                reason: '$label $reason',
              );
              expect(
                inner.top,
                greaterThanOrEqualTo(rect.top - 0.5),
                reason: '$label $reason',
              );
              expect(
                inner.bottom,
                lessThanOrEqualTo(rect.bottom + 0.5),
                reason: '$label $reason',
              );
            }
          }
          expect(t.takeException(), isNull, reason: reason);
          expect(find.byType(BannerSlot), findsNothing, reason: reason);
        }
      }
    },
  );

  testWidgetsOn(TargetPlatform.iOS, 'every_row_is_at_least_56dp_high', (
    t,
  ) async {
    consent.optionsRequired = true;
    await pumpPage(
      t,
      size: const Size(390, 1600),
      firebase: FirebaseStatus.notConfigured,
      tracking: FakeTrackingService(current: TrackingStatus.denied),
    );
    final rows = find.byType(ListTile).evaluate().toList();
    // Two switches, Remove ads, Ad privacy choices, Ad tracking, Privacy
    // policy.
    expect(rows, hasLength(6));
    for (final row in rows) {
      expect(
        t.getRect(find.byWidget(row.widget)).height,
        greaterThanOrEqualTo(56),
        reason: '${row.widget}',
      );
    }
  });

  testWidgetsOn(TargetPlatform.iOS, 'the_tracking_row_says_it_opens_settings', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    await pumpPage(
      t,
      tracking: FakeTrackingService(current: TrackingStatus.denied),
    );
    await scrollTo(t, find.text('Ad tracking'));
    final node = t.getSemantics(
      find.ancestor(
        of: find.text('Ad tracking'),
        matching: find.byType(ListTile),
      ),
    );
    expect(node.hint, contains("Opens your phone's Settings"));
    expect(node.label, contains('Ad tracking'));
    handle.dispose();
  });

  testWidgets('a_double_tap_on_ad_privacy_choices_opens_the_form_once', (
    t,
  ) async {
    final hold = Completer<void>();
    consent
      ..optionsRequired = true
      ..holdShowPrivacyOptions = hold;
    await pumpPage(t);

    await t.tap(find.text('Ad privacy choices'));
    await t.pump();
    await t.tap(find.text('Ad privacy choices'));
    await t.pump();
    expect(consent.privacyOptionsCalls, 1);

    // After the form closes the row works again.
    hold.complete();
    await t.pumpAndSettle();
    consent.holdShowPrivacyOptions = null;
    await t.tap(find.text('Ad privacy choices'));
    await t.pumpAndSettle();
    expect(consent.privacyOptionsCalls, 2);
  });
}
