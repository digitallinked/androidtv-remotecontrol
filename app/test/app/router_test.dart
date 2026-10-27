import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/features/apps/presentation/apps_screen.dart';
import 'package:tv_remote/features/apps/presentation/manage_apps_screen.dart';
import 'package:tv_remote/features/devices/presentation/devices_screen.dart';
import 'package:tv_remote/features/devices/presentation/edit_device_screen.dart';
import 'package:tv_remote/features/pairing/presentation/pairing_screen.dart';
import 'package:tv_remote/features/paywall/domain/paywall_source.dart';
import 'package:tv_remote/features/paywall/presentation/paywall_screen.dart';
import 'package:tv_remote/features/settings/presentation/about_page.dart';
import 'package:tv_remote/features/settings/presentation/appearance_page.dart';
import 'package:tv_remote/features/settings/presentation/help_page.dart';
import 'package:tv_remote/features/settings/presentation/remote_behaviour_page.dart';
import 'package:tv_remote/features/settings/presentation/remote_layout_page.dart';
import 'package:tv_remote/features/settings/presentation/settings_screen.dart';

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
      AppRoutes.manageApps: 'Edit apps',
      AppRoutes.devices: 'Your TVs',
      AppRoutes.settings: 'Settings',
      AppRoutes.settingsAppearance: 'Appearance',
      AppRoutes.settingsRemoteLayout: 'Remote layout',
      AppRoutes.settingsRemoteBehaviour: 'Remote behaviour',
      AppRoutes.settingsHelp: 'Help',
      AppRoutes.settingsAbout: 'About this app',
      AppRoutes.settingsPrivacy: 'Privacy choices',
      '/paywall': 'Premium',
    };
    for (final e in titles.entries) {
      await pumpRouterApp(t, initialLocation: e.key);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(e.value),
        ),
        findsOneWidget,
        reason: e.key,
      );
    }
  });

  testWidgets('every_phase_5_route_builds_its_final_screen_class', (t) async {
    const screens = {
      AppRoutes.apps: AppsScreen,
      AppRoutes.manageApps: ManageAppsScreen,
      AppRoutes.devices: DevicesScreen,
      AppRoutes.settings: SettingsScreen,
      AppRoutes.settingsAppearance: AppearancePage,
      AppRoutes.settingsRemoteLayout: RemoteLayoutPage,
      AppRoutes.settingsRemoteBehaviour: RemoteBehaviourPage,
      AppRoutes.settingsHelp: HelpPage,
      AppRoutes.settingsAbout: AboutPage,
    };
    for (final e in screens.entries) {
      await pumpRouterApp(t, initialLocation: e.key);
      expect(find.byType(e.value), findsOneWidget, reason: e.key);
    }
  });

  testWidgets('settings_child_pages_return_to_one_settings_page', (t) async {
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.settings,
    );
    final router = GoRouter.of(t.element(find.byType(SettingsScreen)));
    for (final path in const [
      AppRoutes.settingsAppearance,
      AppRoutes.settingsRemoteLayout,
      AppRoutes.settingsRemoteBehaviour,
      AppRoutes.settingsHelp,
      AppRoutes.settingsAbout,
      AppRoutes.settingsPrivacy,
    ]) {
      unawaited(router.push(path));
      await t.pumpAndSettle();
      expect(
        find.byType(SettingsScreen, skipOffstage: false),
        findsOneWidget,
        reason: path,
      );
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget, reason: path);
    }
  });

  testWidgets('edit_device_route_round_trips_service_names', (t) async {
    for (final name in [
      'Living Room TV 3',
      'Bravia/4K',
      '100% TV',
      'Télé du salon',
      'manual:192.168.0.20',
    ]) {
      await pumpRouterApp(t, initialLocation: AppRoutes.editDevice(name));
      expect(
        t.widget<EditDeviceScreen>(find.byType(EditDeviceScreen)).serviceName,
        name,
      );
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
      // Pairing a manual TV runs a countdown, so the screen never settles.
      await pumpRouterApp(
        t,
        initialLocation: AppRoutes.pair(name),
        settle: false,
      );
      await t.pump();
      expect(
        t.widget<PairingScreen>(find.byType(PairingScreen)).serviceName,
        name,
      );
      expect(find.text('Pair your TV'), findsOneWidget);
    }
  });

  testWidgets('paywall_route_parses_its_source', (t) async {
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.paywall(source: PaywallSource.themes),
    );
    expect(
      t.widget<PaywallScreen>(find.byType(PaywallScreen)).source,
      PaywallSource.themes,
    );
    for (final location in const ['/paywall?source=bogus', '/paywall']) {
      await pumpRouterApp(t, initialLocation: location);
      expect(
        t.widget<PaywallScreen>(find.byType(PaywallScreen)).source,
        PaywallSource.unknown,
        reason: location,
      );
    }
  });

  testWidgets('every_route_has_a_parameter_free_name', (t) async {
    await pumpRouterApp(t, initialLocation: AppRoutes.settings);
    final container = ProviderScope.containerOf(
      t.element(find.byType(SettingsScreen)),
    );
    final names = <String>[];
    void walk(List<RouteBase> routes) {
      for (final route in routes) {
        if (route is GoRoute) {
          expect(route.name, isNotNull, reason: route.path);
          names.add(route.name!);
        }
        walk(route.routes);
      }
    }

    walk(container.read(appRouterProvider).configuration.routes);
    expect(AppRouteNames.all, hasLength(16));
    expect(names.toSet(), hasLength(names.length), reason: 'duplicate names');
    expect(names, everyElement(isIn(AppRouteNames.all)));
    expect(names.toSet(), AppRouteNames.all);
    expect(AppRouteNames.all, everyElement(matches(RegExp(r'^[a-z_]+$'))));
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
    expect(AppRoutes.editDevice('Bravia/4K'), '/devices/Bravia%2F4K');
    expect(
      AppRoutes.paywall(source: PaywallSource.settings),
      '/paywall?source=settings',
    );
  });
}
