import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/widgets/placeholder_screen.dart';

import '../helpers/pump_router_app.dart';

void main() {
  testWidgets('first_run_shows_onboarding_and_get_started_opens_discover', (
    t,
  ) async {
    final store = await pumpRouterApp(t, initialLocation: AppRoutes.onboarding);
    expect(find.text('Control your TV from your phone'), findsOneWidget);
    await t.tap(find.text('Get started'));
    await t.pumpAndSettle();
    expect(find.text('Choose your TV'), findsOneWidget);
    expect(find.text('No TVs found yet'), findsOneWidget);
    expect(store.onboardingComplete, isTrue);
  });

  testWidgets('every_route_renders_its_titled_screen', (t) async {
    const titles = {
      AppRoutes.apps: 'Apps',
      AppRoutes.devices: 'Devices',
      AppRoutes.settings: 'Settings',
      '/paywall': 'Premium',
    };
    for (final e in titles.entries) {
      await pumpRouterApp(t, initialLocation: e.key);
      expect(find.text(e.value), findsOneWidget);
      expect(find.text('This screen is coming soon.'), findsOneWidget);
    }
  });

  testWidgets('pair_route_round_trips_service_names', (t) async {
    for (final name in [
      'Living Room TV 3',
      'Bravia/4K',
      '100% TV',
      'Télé du salon',
      'manual:192.168.0.5',
    ]) {
      await pumpRouterApp(t, initialLocation: AppRoutes.pair(name));
      expect(
        t.widget<PlaceholderScreen>(find.byType(PlaceholderScreen)).params,
        {'serviceName': name},
      );
      expect(find.text('Pair your TV'), findsOneWidget);
    }
  });

  testWidgets('paywall_route_passes_source', (t) async {
    await pumpRouterApp(t, initialLocation: AppRoutes.paywall(source: 'apps'));
    expect(
      t.widget<PlaceholderScreen>(find.byType(PlaceholderScreen)).params,
      {'source': 'apps'},
    );
  });

  testWidgets('paywall_route_without_source_has_no_params', (t) async {
    await pumpRouterApp(t, initialLocation: AppRoutes.paywallPath);
    expect(
      t.widget<PlaceholderScreen>(find.byType(PlaceholderScreen)).params,
      isEmpty,
    );
  });

  testWidgets('unknown_route_offers_way_back_to_discover', (t) async {
    await pumpRouterApp(t, initialLocation: '/nope');
    expect(find.text('Page not found'), findsOneWidget);
    expect(find.text("We couldn't find that page."), findsOneWidget);
    expect(find.text('This screen is coming soon.'), findsNothing);
    await t.tap(find.text('Back to TVs'));
    await t.pumpAndSettle();
    expect(find.text('Choose your TV'), findsOneWidget);
  });

  test('route_helpers_encode_their_arguments', () {
    expect(AppRoutes.pair('Bravia/4K'), '/pair/Bravia%2F4K');
    expect(AppRoutes.paywall(source: 'a b'), '/paywall?source=a+b');
  });
}
