import 'dart:async';
import 'dart:ui' show CheckedState;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/app_links.dart';
import 'package:tv_remote/app/flavor.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/ads/banner_slot.dart';
import 'package:tv_remote/core/analytics/app_analytics.dart';
import 'package:tv_remote/core/links/link_opener.dart';
import 'package:tv_remote/core/purchases/premium.dart';
import 'package:tv_remote/core/purchases/purchase_service.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/features/paywall/presentation/paywall_screen.dart';
import 'package:tv_remote/features/paywall/presentation/widgets/plan_tile.dart';
import 'package:tv_remote/features/remote/presentation/remote_screen.dart';
import 'package:tv_remote/features/settings/presentation/settings_screen.dart';

import '../../helpers/fake_purchase_service.dart';
import '../../helpers/nonlinear_text_scaler.dart';
import '../../helpers/platform_override.dart';
import '../../helpers/pump_router_app.dart';
import '../../helpers/recording_analytics_sink.dart';
import '../../helpers/recording_link_opener.dart';

const _termsAndroid =
    'Payment is charged to your Google Play account. Subscriptions renew '
    'automatically until you cancel them in Google Play, and you keep '
    'Premium until the end of the period you paid for.';
const _termsIos =
    'Payment is charged to your Apple ID. Subscriptions renew automatically '
    'unless you cancel at least 24 hours before the end of the current '
    'period. Manage or cancel them in your Apple ID settings.';
const _welcome = 'Welcome to Premium. Thank you!';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late FakePurchaseService fake;
  late RecordingAnalyticsSink sink;
  late RecordingLinkOpener links;

  setUp(() {
    fake = FakePurchaseService(offer: testOffer());
    sink = RecordingAnalyticsSink();
    links = RecordingLinkOpener();
  });

  Future<SettingsStore> pumpPaywall(
    WidgetTester t, {
    String location = '/paywall?source=settings',
    Size size = const Size(390, 1800),
    double textScale = 1,
    TextScaler? textScaler,
    Brightness brightness = Brightness.light,
    bool settle = true,
    CachedPremium? cachedPremium,
    List<Override> overrides = const [],
  }) {
    t.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    return pumpRouterApp(
      t,
      initialLocation: location,
      textScale: textScale,
      textScaler: textScaler,
      brightness: brightness,
      settle: settle,
      prepareSettings: (store) async {
        // Usage statistics are on, so every event reaches the recording sink.
        await store.setShareUsageStats(true);
        if (cachedPremium != null) await store.setCachedPremium(cachedPremium);
      },
      overrides: [
        purchaseServiceProvider.overrideWithValue(fake),
        analyticsSinkProvider.overrideWithValue(sink),
        analyticsDebugBuildProvider.overrideWithValue(true),
        linkOpenerProvider.overrideWithValue(links),
        ...overrides,
      ],
    );
  }

  ProviderContainer containerOf(WidgetTester t) =>
      ProviderScope.containerOf(t.element(find.byType(PaywallScreen)));

  Finder snack(String text) =>
      find.descendant(of: find.byType(SnackBar), matching: find.text(text));

  Future<void> tapContinue(WidgetTester t) async {
    await t.tap(find.widgetWithText(FilledButton, 'Continue'));
    await t.pumpAndSettle();
  }

  Future<void> clearSnack(WidgetTester t) async {
    await t.pump(const Duration(seconds: 6));
    await t.pumpAndSettle();
  }

  PremiumPlanKind? selectedPlan(WidgetTester t) => t
      .widget<RadioGroup<PremiumPlanKind>>(
        find.byType(RadioGroup<PremiumPlanKind>),
      )
      .groupValue;

  group('plans', () {
    testWidgets('paywall_shows_terms_restore_privacy', (t) async {
      await pumpPaywall(t);
      expect(find.text('Restore purchases'), findsOneWidget);
      expect(find.text('Terms of use'), findsOneWidget);
      expect(find.text('Privacy policy'), findsOneWidget);
      expect(find.text(_termsAndroid), findsOneWidget);
      expect(find.text(_termsIos), findsNothing);

      // The price and the renewal terms sit together under each plan.
      expect(find.text('RM 4.99 per month'), findsOneWidget);
      expect(find.text('Renews every month until you cancel.'), findsOneWidget);
      expect(find.text('RM 29.99 per year'), findsOneWidget);
      expect(find.text('Renews every year until you cancel.'), findsOneWidget);
      expect(find.text('RM 59.90, one payment'), findsOneWidget);
      expect(find.text('Pay once. No subscription.'), findsOneWidget);
      expect(
        find.textContaining('Everything else stays free'),
        findsOneWidget,
      );
      // The value comes first.
      expect(find.text('No ads'), findsOneWidget);
      expect(find.text('Colour styles'), findsOneWidget);
      double top(String text) => t.getTopLeft(find.text(text)).dy;
      expect(top('No ads') < top('Choose a plan'), isTrue);
      expect(top('Choose a plan') < top('RM 4.99 per month'), isTrue);
      expect(top('RM 59.90, one payment') < top('Continue'), isTrue);
      expect(top('Continue') < top('Restore purchases'), isTrue);
      expect(top('Restore purchases') < top(_termsAndroid), isTrue);
      expect(top(_termsAndroid) < top('Terms of use'), isTrue);

      await t.tap(find.text('Terms of use'));
      await t.pump();
      await t.tap(find.text('Privacy policy'));
      await t.pump();
      expect(links.opened, [AppLinks.terms, AppLinks.privacyPolicy]);
    });

    testWidgetsOn(TargetPlatform.iOS, 'paywall_shows_the_apple_terms_on_ios', (
      t,
    ) async {
      await pumpPaywall(t);
      expect(find.text(_termsIos), findsOneWidget);
      expect(find.text(_termsAndroid), findsNothing);
    });

    testWidgets('yearly_preselected_with_an_honest_saving', (t) async {
      await pumpPaywall(t);
      expect(selectedPlan(t), PremiumPlanKind.yearly);
      expect(find.text('Best value'), findsOneWidget);
      expect(find.text('Save 49%'), findsOneWidget);
    });

    testWidgets('no_badge_when_yearly_is_no_cheaper', (t) async {
      fake.offer = testOffer(yearly: 59.88);
      await pumpPaywall(t);
      expect(selectedPlan(t), PremiumPlanKind.monthly);
      expect(find.text('Best value'), findsNothing);
      expect(find.textContaining('Save'), findsNothing);
    });

    testWidgets('lifetime_is_never_preselected', (t) async {
      fake.offer = testOffer(hasYearly: false);
      await pumpPaywall(t);
      expect(selectedPlan(t), PremiumPlanKind.monthly);
      expect(find.text('Best value'), findsNothing);
    });

    testWidgets('choosing_a_plan_changes_what_continue_buys', (t) async {
      await pumpPaywall(t);
      await t.tap(find.text('RM 59.90, one payment'));
      await t.pumpAndSettle();
      expect(selectedPlan(t), PremiumPlanKind.lifetime);
      await tapContinue(t);
      expect(fake.purchases, [PremiumPlanKind.lifetime]);
    });

    testWidgets('plan_tiles_are_a_labelled_radio_group', (t) async {
      final handle = t.ensureSemantics();
      await pumpPaywall(t);
      final tiles = find.byType(PlanTile);
      expect(tiles, findsNWidgets(3));
      final yearly = t.getSemantics(tiles.at(1));
      expect(yearly.label, contains('Yearly'));
      expect(yearly.label, contains('RM 29.99 per year'));
      expect(yearly.label, contains('Best value'));
      expect(
        yearly.getSemanticsData().flagsCollection.isChecked,
        CheckedState.isTrue,
      );
      expect(
        t
            .getSemantics(tiles.at(0))
            .getSemanticsData()
            .flagsCollection
            .isChecked,
        CheckedState.isFalse,
      );
      for (var i = 0; i < 3; i++) {
        expect(t.getSize(tiles.at(i)).height, greaterThanOrEqualTo(48));
      }
      handle.dispose();
    });
  });

  group('navigation', () {
    testWidgets('close_returns_to_source_route', (t) async {
      await pumpPaywall(t, location: AppRoutes.settings);
      await t.tap(find.text('Premium'));
      await t.pumpAndSettle();
      expect(find.byType(PaywallScreen), findsOneWidget);

      final close = find.widgetWithIcon(IconButton, Icons.close);
      expect(find.byTooltip('Close'), findsOneWidget);
      expect(t.getSize(close).shortestSide, greaterThanOrEqualTo(48));
      expect(
        t.getTopLeft(close).dx < t.getTopLeft(find.text('Premium')).dx,
        isTrue,
        reason: 'the close button leads the title',
      );
      await t.tap(close);
      await t.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.byType(PaywallScreen), findsNothing);

      // Opened with nothing below it, the close button goes to the remote.
      await pumpPaywall(t, location: '/paywall?source=themes');
      await t.tap(find.widgetWithIcon(IconButton, Icons.close));
      await t.pumpAndSettle();
      expect(find.byType(RemoteScreen), findsOneWidget);
      expect(find.byType(PaywallScreen), findsNothing);
    });

    testWidgets('paywall_view_logged_with_source_and_variant', (t) async {
      await pumpPaywall(t);
      expect(sink.eventNames, ['paywall_view']);
      expect(sink.events.single.params, {'source': 'settings', 'variant': 'a'});

      sink.events.clear();
      await pumpPaywall(t, location: '/paywall?source=themes');
      expect(sink.events.single.params, {'source': 'themes', 'variant': 'a'});

      sink.events.clear();
      await pumpPaywall(t, location: '/paywall?source=nonsense');
      expect(sink.events.single.params, {'source': 'unknown', 'variant': 'a'});
    });

    testWidgets('paywall_has_no_banner', (t) async {
      await pumpPaywall(t);
      expect(find.byType(BannerSlot), findsNothing);
      await pumpPaywall(
        t,
        cachedPremium: (active: true, expiresAt: null),
      );
      expect(find.byType(BannerSlot), findsNothing);
      fake.offer = null;
      await pumpPaywall(t);
      expect(find.byType(BannerSlot), findsNothing);
    });
  });

  group('purchase', () {
    testWidgets('purchase_success_closes_and_unlocks', (t) async {
      fake.nextPurchase = const Purchased(EntitlementSnapshot(active: true));
      await pumpPaywall(t, location: AppRoutes.settings);
      expect(find.text('No ads and extra colour styles'), findsOneWidget);
      await t.tap(find.text('Premium'));
      await t.pumpAndSettle();
      await tapContinue(t);

      expect(fake.purchases, [PremiumPlanKind.yearly]);
      expect(snack(_welcome), findsOneWidget);
      // Back on the screen it was opened from, now with Premium.
      expect(find.byType(PaywallScreen), findsNothing);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('You have Premium. Thank you!'), findsOneWidget);
      final container = ProviderScope.containerOf(
        t.element(find.byType(SettingsScreen)),
      );
      expect(container.read(premiumProvider).isPremium, isTrue);
      expect(sink.eventNames, ['paywall_view', 'purchase_success']);
      expect(sink.events.last.params, {'product': 'premium_yearly'});
    });

    testWidgets('cancelled_purchase_stays_quietly', (t) async {
      fake.nextPurchase = const PurchaseCancelled();
      await pumpPaywall(t);
      await tapContinue(t);
      expect(fake.purchases, [PremiumPlanKind.yearly]);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(PaywallScreen), findsOneWidget);
      expect(
        t
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
            .onPressed,
        isNotNull,
      );
      expect(containerOf(t).read(premiumProvider).isPremium, isFalse);
      expect(sink.eventNames, ['paywall_view']);
    });

    testWidgets('pending_and_failed_purchases_say_so', (t) async {
      await pumpPaywall(t);
      const cases = <(PurchaseOutcome, String)>[
        (
          PurchasePending(),
          'Your purchase is waiting for approval. Premium starts as soon as '
              "it's complete.",
        ),
        (
          PurchaseFailed(PurchaseFailure.network),
          "Couldn't reach the store. Check your internet connection and try "
              'again.',
        ),
        (
          PurchaseFailed(PurchaseFailure.notAllowed),
          "Purchases aren't allowed on this phone.",
        ),
        (
          PurchaseFailed(PurchaseFailure.alreadyOwned),
          'You already own Premium. Tap Restore purchases to get it back.',
        ),
        (
          PurchaseFailed(PurchaseFailure.storeProblem),
          "The purchase didn't go through. Try again.",
        ),
        (
          PurchaseFailed(PurchaseFailure.unknown),
          "The purchase didn't go through. Try again.",
        ),
      ];
      for (final (outcome, message) in cases) {
        fake.nextPurchase = outcome;
        await tapContinue(t);
        expect(snack(message), findsOneWidget, reason: '$outcome');
        expect(find.byType(PaywallScreen), findsOneWidget);
        await clearSnack(t);
      }
      expect(sink.eventNames, ['paywall_view']);
      expect(containerOf(t).read(premiumProvider).isPremium, isFalse);
    });

    testWidgets('busy_purchase_disables_the_buttons', (t) async {
      final hold = Completer<void>();
      fake.holdPurchase = hold;
      await pumpPaywall(t);
      await t.tap(find.widgetWithText(FilledButton, 'Continue'));
      await t.pump();

      expect(find.text('Confirming your purchase…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        t
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
            .onPressed,
        isNull,
      );
      expect(
        t
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Restore purchases'),
            )
            .onPressed,
        isNull,
      );
      // A plan can't be changed while the store is open either.
      await t.tap(find.text('RM 4.99 per month'));
      await t.pump();
      expect(selectedPlan(t), PremiumPlanKind.yearly);
      expect(fake.purchases, hasLength(1));

      hold.complete();
      await t.pumpAndSettle();
      expect(find.text('Confirming your purchase…'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        t
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
            .onPressed,
        isNotNull,
      );
    });
  });

  group('restore', () {
    testWidgets('restore_outcomes', (t) async {
      await pumpPaywall(t);

      fake.nextRestore = RestoreOutcome.nothingToRestore;
      await t.tap(find.text('Restore purchases'));
      await t.pumpAndSettle();
      expect(snack('No purchases found for this account.'), findsOneWidget);
      await clearSnack(t);

      fake.nextRestore = RestoreOutcome.failed;
      await t.tap(find.text('Restore purchases'));
      await t.pumpAndSettle();
      expect(snack("Couldn't restore purchases. Try again."), findsOneWidget);
      await clearSnack(t);
      expect(sink.eventNames, ['paywall_view']);
      expect(fake.restoreCalls, 2);

      fake
        ..nextRestore = RestoreOutcome.restoredPremium
        ..restoreSnapshot = const EntitlementSnapshot(active: true);
      await t.tap(find.text('Restore purchases'));
      await t.pumpAndSettle();
      expect(snack('Purchases restored. You have Premium.'), findsOneWidget);
      expect(find.text('You have Premium'), findsOneWidget);
      expect(sink.eventNames, ['paywall_view', 'restore_success']);
      expect(sink.events.last.params, isEmpty);
    });
  });

  group('states', () {
    testWidgets('offers_unavailable_shows_retry', (t) async {
      fake.offer = null;
      await pumpPaywall(t);
      expect(find.text("Premium isn't available right now"), findsOneWidget);
      expect(
        find.text('Check your internet connection and try again.'),
        findsOneWidget,
      );
      expect(find.text('Continue'), findsNothing);
      expect(fake.loadOfferCalls, 1);

      fake.offer = testOffer();
      await t.tap(find.text('Try again'));
      await t.pumpAndSettle();
      expect(fake.loadOfferCalls, 2);
      expect(find.text('RM 29.99 per year'), findsOneWidget);
      expect(find.text("Premium isn't available right now"), findsNothing);
      // One view, however many times the plans were asked for.
      expect(sink.eventNames, ['paywall_view']);
    });

    testWidgets('already_premium_shows_thanks_and_manage', (t) async {
      final expires = DateTime.now().add(const Duration(days: 30));
      await pumpPaywall(t, cachedPremium: (active: true, expiresAt: expires));
      expect(find.text('You have Premium'), findsOneWidget);
      expect(
        find.text(
          'Thank you for supporting the app. There are no ads, and every '
          'colour style is yours.',
        ),
        findsOneWidget,
      );
      expect(find.text('Continue'), findsNothing);
      expect(find.byType(PlanTile), findsNothing);
      expect(find.text('Restore purchases'), findsOneWidget);
      expect(fake.loadOfferCalls, 0);

      await t.tap(find.text('Manage subscription'));
      await t.pump();
      expect(
        links.opened.single,
        Uri.parse(
          'https://play.google.com/store/account/subscriptions'
          '?package=com.digitallinked.atvremote.dev',
        ),
      );
    });

    testWidgets('lifetime_premium_has_no_manage_button', (t) async {
      await pumpPaywall(t, cachedPremium: (active: true, expiresAt: null));
      expect(find.text('You have Premium'), findsOneWidget);
      expect(find.text('Lifetime Premium: it never expires.'), findsOneWidget);
      expect(find.text('Manage subscription'), findsNothing);
      expect(find.text('Restore purchases'), findsOneWidget);
    });

    test('manage_subscriptions_points_at_each_store', () {
      expect(
        AppLinks.manageSubscriptions(Flavor.prod, TargetPlatform.android),
        Uri.parse(
          'https://play.google.com/store/account/subscriptions'
          '?package=com.digitallinked.atvremote',
        ),
      );
      expect(
        AppLinks.manageSubscriptions(Flavor.dev, TargetPlatform.iOS),
        Uri.parse('https://apps.apple.com/account/subscriptions'),
      );
    });

    testWidgets('plans_load_with_a_spinner_first', (t) async {
      final hold = Completer<void>();
      fake = _SlowOfferService(hold, testOffer());
      await pumpPaywall(t, settle: false);
      expect(find.text('Loading plans…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      hold.complete();
      await t.pumpAndSettle();
      expect(find.text('Loading plans…'), findsNothing);
      expect(find.text('RM 29.99 per year'), findsOneWidget);
    });
  });

  group('layout', () {
    final scalers = <String, TextScaler>{
      'linear': const TextScaler.linear(2),
      'nonlinear': const NonlinearTwoXScaler(),
    };

    Future<void> expectInside(WidgetTester t, List<String> texts) async {
      for (final text in texts) {
        final finder = find.text(text);
        await t.scrollUntilVisible(
          finder,
          150,
          scrollable: find.byType(Scrollable).first,
        );
        expect(t.takeException(), isNull, reason: text);
        final rect = t.getRect(finder);
        expect(rect.left >= 0 && rect.right <= 320, isTrue, reason: text);
      }
    }

    for (final brightness in Brightness.values) {
      for (final scaler in scalers.entries) {
        final name = '${scaler.key}_${brightness.name}';
        testWidgets(
          'paywall_fits_320dp_at_200_percent_text_$name',
          (t) async {
            final semantics = t.ensureSemantics();
            Future<void> pump({
              CachedPremium? premium,
              bool offers = true,
            }) async {
              fake.offer = offers ? testOffer() : null;
              await pumpPaywall(
                t,
                size: const Size(320, 640),
                textScaler: scaler.value,
                brightness: brightness,
                cachedPremium: premium,
              );
            }

            // Plans.
            await pump();
            expect(t.takeException(), isNull);
            await expectInside(t, [
              'Make the remote yours',
              'No ads',
              'Colour styles',
              'Choose a plan',
              'Best value',
              'Save 49%',
              'RM 29.99 per year',
              'RM 59.90, one payment',
              'Pay once. No subscription.',
              'Continue',
              'Restore purchases',
              _termsAndroid,
              'Terms of use',
              'Privacy policy',
            ]);
            await expectLater(t, meetsGuideline(textContrastGuideline));
            await expectLater(t, meetsGuideline(androidTapTargetGuideline));
            await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
            final button = find.widgetWithText(FilledButton, 'Continue');
            expect(t.getSize(button).height, greaterThanOrEqualTo(48));
            expect(
              t.getSize(find.byType(PlanTile).first).height,
              greaterThanOrEqualTo(48),
            );

            // Already Premium.
            await pump(premium: (active: true, expiresAt: DateTime(2100)));
            expect(t.takeException(), isNull);
            await expectInside(t, [
              'You have Premium',
              'Manage subscription',
              'Restore purchases',
            ]);
            await expectLater(t, meetsGuideline(textContrastGuideline));
            await expectLater(t, meetsGuideline(androidTapTargetGuideline));
            await expectLater(t, meetsGuideline(labeledTapTargetGuideline));

            // No plans.
            await pump(offers: false);
            expect(t.takeException(), isNull);
            await expectInside(t, [
              "Premium isn't available right now",
              'Check your internet connection and try again.',
              'Try again',
            ]);
            await expectLater(t, meetsGuideline(androidTapTargetGuideline));
            semantics.dispose();
          },
        );
      }
    }
  });
}

/// A service whose plans arrive only when [release] completes.
class _SlowOfferService extends FakePurchaseService {
  _SlowOfferService(this.release, PremiumOffer offer) : super(offer: offer);

  final Completer<void> release;

  @override
  Future<PremiumOffer?> loadOffer() async {
    await release.future;
    return super.loadOffer();
  }
}
