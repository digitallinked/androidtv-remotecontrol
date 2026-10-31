import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/ads/ads_service.dart';
import 'package:tv_remote/core/ads/consent_service.dart';
import 'package:tv_remote/core/ads/tracking_service.dart';
import 'package:tv_remote/core/config/app_config.dart';
import 'package:tv_remote/core/purchases/premium.dart';
import 'package:tv_remote/core/purchases/purchase_service.dart';
import 'package:tv_remote/features/paywall/domain/paywall_source.dart';

import '../helpers/fake_ads_sdk.dart';
import '../helpers/fake_consent_service.dart';
import '../helpers/fake_purchase_service.dart';
import '../helpers/fake_tracking_service.dart';
import '../helpers/gather_consent.dart';
import '../helpers/nonlinear_text_scaler.dart';
import '../helpers/pump_router_app.dart';
import '../helpers/test_app_config.dart';
import '../helpers/test_premium.dart';

/// A Phase 6 screen: how to open it, and the texts that carry its meaning
/// (each must be reachable on screen, at any size).
typedef _Screen = ({
  String route,
  List<Override> Function() overrides,
  bool ios,
  bool banner,
  List<String> texts,
});

/// The tracking pre-prompt's message (`trackingPrepromptBody`).
const String _prepromptBody =
    'The free app shows a small ad at the bottom of this screen. Next, your '
    'iPhone asks whether the app may use your activity in other apps to '
    'choose ads. You see the same number of ads whatever you choose, and the '
    'remote works the same.';

final Map<String, _Screen> _screens = {
  'paywall_ready': (
    route: AppRoutes.paywall(source: PaywallSource.settings),
    overrides: () => [
      purchaseServiceProvider.overrideWithValue(
        FakePurchaseService(offer: testOffer()),
      ),
    ],
    ios: false,
    banner: false,
    texts: [
      'Make the remote yours',
      'Choose a plan',
      'Best value',
      'Continue',
      'Restore purchases',
      'Terms of use',
      'Privacy policy',
    ],
  ),
  'paywall_active': (
    route: AppRoutes.paywall(source: PaywallSource.settings),
    overrides: () => [
      premiumProvider.overrideWith(
        () => TestPremium(
          PremiumState(
            isPremium: true,
            known: true,
            expiresAt: DateTime.utc(2100),
          ),
        ),
      ),
    ],
    ios: false,
    banner: false,
    texts: ['You have Premium', 'Manage subscription', 'Restore purchases'],
  ),
  'settings_privacy': (
    route: AppRoutes.settingsPrivacy,
    // The ad privacy row shows too.
    overrides: () => [
      consentServiceProvider.overrideWithValue(
        FakeConsentService(optionsRequired: true),
      ),
    ],
    ios: false,
    banner: false,
    texts: [
      'Share usage statistics',
      'Share crash reports',
      'Remove ads with Premium',
      'Ad privacy choices',
    ],
  ),
  'settings_appearance_styles': (
    route: AppRoutes.settingsAppearance,
    overrides: () => const [],
    ios: false,
    banner: false,
    texts: ['Colour style', 'Ocean', 'Ember', 'Midnight'],
  ),
  'settings_with_banner': (
    route: AppRoutes.settings,
    overrides: () => [
      adsSdkProvider.overrideWithValue(FakeAdsSdk(loads: true)),
    ],
    ios: false,
    banner: true,
    texts: ['Premium', 'Privacy choices', 'Advertisement'],
  ),
  'update_gate': (
    route: AppRoutes.settings,
    overrides: () => [
      appConfigProvider.overrideWith(
        () => TestAppConfig({'min_supported_version': '9.0.0'}),
      ),
    ],
    ios: false,
    banner: false,
    texts: ['Update required', 'Update'],
  ),
  'tracking_preprompt': (
    route: AppRoutes.settings,
    overrides: () => [
      adsSdkProvider.overrideWithValue(FakeAdsSdk(loads: true)),
      trackingServiceProvider.overrideWithValue(
        FakeTrackingService(current: TrackingStatus.notDetermined),
      ),
    ],
    ios: true,
    banner: true,
    texts: [
      'About ads in this app',
      _prepromptBody,
      'Continue',
    ],
  ),
};

void main() {
  /// Opens [name] as a user would meet it. The banner screens gather consent
  /// first, as the remote does; the pre-prompt then opens over the hub.
  Future<void> open(
    WidgetTester t,
    String name, {
    Brightness brightness = Brightness.light,
    Size size = const Size(390, 844),
    TextScaler? textScaler,
  }) async {
    final screen = _screens[name]!;
    t.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpRouterApp(
      t,
      initialLocation: screen.route,
      brightness: brightness,
      textScaler: textScaler,
      overrides: screen.overrides(),
    );
    if (screen.banner) await gatherConsent(t);
    if (name == 'tracking_preprompt') {
      expect(find.byType(Dialog), findsOneWidget, reason: name);
    } else if (screen.banner) {
      expect(
        find.byKey(const ValueKey('fake_banner')),
        findsOneWidget,
        reason: name,
      );
    }
  }

  /// Runs [body] as iOS when [ios], restoring the platform afterwards.
  Future<void> on(
    Future<void> Function() body, {
    required bool ios,
  }) async {
    if (!ios) return body();
    final previous = debugDefaultTargetPlatformOverride;
    addTearDown(() => debugDefaultTargetPlatformOverride = previous);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = previous;
    }
  }

  for (final b in Brightness.values) {
    for (final name in _screens.keys) {
      final ios = _screens[name]!.ios;
      _semanticsTest('${name}_meets_text_contrast_${b.name}', (t) async {
        await on(ios: ios, () async {
          await open(t, name, brightness: b);
          await expectLater(t, meetsGuideline(textContrastGuideline));
        });
      });

      _semanticsTest('${name}_meets_tap_target_guidelines_${b.name}', (
        t,
      ) async {
        await on(ios: ios, () async {
          await open(t, name, brightness: b);
          await expectLater(t, meetsGuideline(androidTapTargetGuideline));
          await expectLater(t, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
        });
      });
    }
  }

  /// Opens every screen at 320 dp in both themes with [textScaler], and
  /// checks that nothing overflows and every text that carries meaning can
  /// be brought fully onto the screen.
  Future<void> fitEverywhere(WidgetTester t, TextScaler textScaler) async {
    const size = Size(320, 640);
    for (final b in Brightness.values) {
      for (final e in _screens.entries) {
        final reason = '${e.key} ${b.name}';
        await on(ios: e.value.ios, () async {
          await open(
            t,
            e.key,
            brightness: b,
            size: size,
            textScaler: textScaler,
          );
          expect(t.takeException(), isNull, reason: reason);
          for (final text in e.value.texts) {
            final finder = find.text(text);
            if (finder.evaluate().isEmpty) {
              await t.scrollUntilVisible(
                finder,
                150,
                scrollable: find.byType(Scrollable).first,
              );
            }
            await t.ensureVisible(finder.first);
            await t.pumpAndSettle();
            expect(t.takeException(), isNull, reason: '$reason $text');
            final rect = t.getRect(finder.first);
            final why = '$reason "$text" at $rect';
            expect(
              rect.left >= 0 && rect.right <= size.width,
              isTrue,
              reason: why,
            );
            if (rect.height <= size.height) {
              expect(
                rect.top >= 0 && rect.bottom <= size.height,
                isTrue,
                reason: why,
              );
              continue;
            }
            // A paragraph taller than the screen (the pre-prompt's body at
            // 200% in a dialog) must scroll: its first and its last line can
            // each be brought onto the screen.
            final position = Scrollable.of(
              t.element(finder.first),
            ).position;
            position.jumpTo(position.minScrollExtent);
            await t.pump();
            expect(
              t.getRect(finder.first).top,
              greaterThanOrEqualTo(0),
              reason: why,
            );
            position.jumpTo(position.maxScrollExtent);
            await t.pump();
            expect(
              t.getRect(finder.first).bottom,
              lessThanOrEqualTo(size.height),
              reason: why,
            );
          }
        });
      }
    }
  }

  testWidgets('every_phase6_screen_fits_320dp_at_200_percent_text', (t) async {
    await fitEverywhere(t, const TextScaler.linear(2));
  });

  testWidgets('every_phase6_screen_fits_a_non_linear_text_scaler', (t) async {
    await fitEverywhere(t, const NonlinearTwoXScaler());
  });

  _semanticsTest('the_banner_is_announced_once_as_an_advertisement', (t) async {
    for (final route in [AppRoutes.settings, AppRoutes.apps]) {
      t.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await pumpRouterApp(
        t,
        initialLocation: route,
        overrides: [adsSdkProvider.overrideWithValue(FakeAdsSdk(loads: true))],
      );
      await gatherConsent(t);
      expect(find.byKey(const ValueKey('fake_banner')), findsOneWidget);

      // Walk the whole semantics tree: one node says "Advertisement", and
      // the label band's text is not a second one.
      var root = t.getSemantics(find.byType(Scaffold).first);
      while (root.parent != null) {
        root = root.parent!;
      }
      final labelled = <SemanticsNode>[];
      void visit(SemanticsNode node) {
        if (node.label.contains('Advertisement')) labelled.add(node);
        node.visitChildren((child) {
          visit(child);
          return true;
        });
      }

      visit(root);
      expect(labelled, hasLength(1), reason: route);
      expect(labelled.single.label, 'Advertisement', reason: route);
      // It holds the ad: the creative is inside the announced container.
      expect(
        labelled.single.rect.height,
        greaterThanOrEqualTo(48 + 60),
        reason: route,
      );
    }
  });
}

/// Runs [body] with semantics on and releases the handle however it ends.
/// The framework checks for live handles before any tear-down runs, so
/// `addTearDown(handle.dispose)` would come too late.
Future<void> _withSemantics(
  WidgetTester t,
  Future<void> Function() body,
) async {
  final handle = t.ensureSemantics();
  try {
    await body();
  } finally {
    handle.dispose();
  }
}

/// A `testWidgets` that runs with semantics on (see [_withSemantics]).
void _semanticsTest(
  String description,
  Future<void> Function(WidgetTester t) body,
) => testWidgets(description, (t) => _withSemantics(t, () => body(t)));
