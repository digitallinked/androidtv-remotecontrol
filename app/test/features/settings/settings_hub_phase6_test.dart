import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/purchases/premium.dart';
import 'package:tv_remote/features/paywall/domain/paywall_source.dart';
import 'package:tv_remote/features/paywall/presentation/paywall_screen.dart';

import '../../helpers/pump_router_app.dart';
import '../../helpers/test_premium.dart';

void main() {
  Finder appBarTitle(String title) =>
      find.descendant(of: find.byType(AppBar), matching: find.text(title));

  Future<void> reveal(WidgetTester t, Finder target) async {
    await t.scrollUntilVisible(
      target,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(target);
    await t.pumpAndSettle();
  }

  testWidgets('hub_has_premium_and_privacy_rows_after_appearance', (t) async {
    t.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpRouterApp(t, initialLocation: AppRoutes.settings);

    double top(String text) => t.getTopLeft(find.text(text)).dy;
    final appearance = find.text('Appearance');
    final premium = find.text('Premium');
    final privacy = find.text('Privacy choices');
    await reveal(t, privacy);
    expect(appearance, findsOneWidget);
    expect(premium, findsOneWidget);
    expect(find.text('No ads and extra colour styles'), findsOneWidget);
    expect(
      find.text('Usage statistics, crash reports and ads'),
      findsOneWidget,
    );
    expect(top('Appearance') < top('Premium'), isTrue);
    expect(top('Premium') < top('Privacy choices'), isTrue);
    expect(top('Privacy choices') < top('Help'), isTrue);

    await t.tap(premium);
    await t.pumpAndSettle();
    expect(
      t.widget<PaywallScreen>(find.byType(PaywallScreen)).source,
      PaywallSource.settings,
    );
    // The paywall closes with a close button, not a back arrow.
    await t.tap(find.byTooltip('Close'));
    await t.pumpAndSettle();

    await reveal(t, privacy);
    await t.tap(privacy);
    await t.pumpAndSettle();
    expect(appBarTitle('Privacy choices'), findsOneWidget);
  });

  testWidgets('hub_fits_320dp_at_200_percent_text_with_the_new_rows', (
    t,
  ) async {
    t.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.settings,
      textScale: 2,
    );
    expect(t.takeException(), isNull);
    for (final row in const ['Premium', 'Privacy choices']) {
      await reveal(t, find.text(row));
      expect(t.takeException(), isNull, reason: row);
      final rect = t.getRect(find.text(row));
      expect(rect.left >= 0 && rect.right <= 320, isTrue, reason: row);
      final tile = find.ancestor(
        of: find.text(row),
        matching: find.byType(ListTile),
      );
      expect(t.getSize(tile).height, greaterThanOrEqualTo(56), reason: row);
    }
  });

  testWidgets('hub_premium_row_reflects_premium', (t) async {
    t.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpRouterApp(t, initialLocation: AppRoutes.settings);
    await reveal(t, find.text('Premium'));
    expect(find.text('No ads and extra colour styles'), findsOneWidget);
    expect(find.text('You have Premium. Thank you!'), findsNothing);

    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.settings,
      overrides: [
        premiumProvider.overrideWith(
          () => TestPremium(const PremiumState(isPremium: true, known: true)),
        ),
      ],
    );
    await reveal(t, find.text('Premium'));
    expect(find.text('You have Premium. Thank you!'), findsOneWidget);
    expect(find.text('No ads and extra colour styles'), findsNothing);
  });
}
