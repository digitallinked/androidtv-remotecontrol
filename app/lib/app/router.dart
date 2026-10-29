import 'package:atv_remote/atv_remote.dart' show DiscoveredTv;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/widgets/placeholder_screen.dart';
import 'package:tv_remote/core/analytics/analytics_route_observer.dart';
import 'package:tv_remote/core/analytics/app_analytics.dart';
import 'package:tv_remote/core/device/page_route_observer.dart';
import 'package:tv_remote/core/storage/device_repository.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/features/apps/presentation/apps_screen.dart';
import 'package:tv_remote/features/apps/presentation/manage_apps_screen.dart';
import 'package:tv_remote/features/devices/presentation/devices_screen.dart';
import 'package:tv_remote/features/devices/presentation/edit_device_screen.dart';
import 'package:tv_remote/features/discovery/presentation/discovery_screen.dart';
import 'package:tv_remote/features/onboarding/presentation/onboarding_screen.dart';
import 'package:tv_remote/features/pairing/presentation/pairing_screen.dart';
import 'package:tv_remote/features/paywall/domain/paywall_source.dart';
import 'package:tv_remote/features/paywall/presentation/paywall_screen.dart';
import 'package:tv_remote/features/remote/presentation/remote_screen.dart';
import 'package:tv_remote/features/settings/presentation/about_page.dart';
import 'package:tv_remote/features/settings/presentation/appearance_page.dart';
import 'package:tv_remote/features/settings/presentation/help_page.dart';
import 'package:tv_remote/features/settings/presentation/privacy_choices_page.dart';
import 'package:tv_remote/features/settings/presentation/remote_behaviour_page.dart';
import 'package:tv_remote/features/settings/presentation/remote_layout_page.dart';
import 'package:tv_remote/features/settings/presentation/settings_screen.dart';

part 'router.g.dart';

/// Route paths and the helpers that build the parameterised ones.
abstract final class AppRoutes {
  /// First-run introduction.
  static const onboarding = '/onboarding';

  /// List of TVs found on the network.
  static const discover = '/discover';

  /// The remote control.
  static const remote = '/remote';

  /// Apps on the TV.
  static const apps = '/apps';

  /// Edit apps: add, reorder and remove app shortcuts.
  static const manageApps = '/apps/manage';

  /// Saved TVs.
  static const devices = '/devices';

  /// App settings.
  static const settings = '/settings';

  /// App settings opened before pairing (from discovery or the no-TV remote):
  /// leaving it never shows an interstitial (Ruling P7-R7).
  static const settingsFromSetup = '/settings?from=setup';

  /// Settings: theme and language.
  static const settingsAppearance = '/settings/appearance';

  /// Settings: touchpad or D-pad, and the row above it.
  static const settingsRemoteLayout = '/settings/remote-layout';

  /// Settings: haptics, Smooth Press, screen and keyboard.
  static const settingsRemoteBehaviour = '/settings/remote-behaviour';

  /// Settings: troubleshooting and common questions.
  static const settingsHelp = '/settings/help';

  /// Settings: version, licences and credits.
  static const settingsAbout = '/settings/about';

  /// Settings: usage statistics, crash reports and ads.
  static const settingsPrivacy = '/settings/privacy';

  /// Path of the premium screen, without its query.
  static const paywallPath = '/paywall';

  /// Edit page of the saved TV [serviceName]; the name is percent-encoded.
  static String editDevice(String serviceName) =>
      '/devices/${Uri.encodeComponent(serviceName)}';

  /// Pairing with the TV named [serviceName]. The name is percent-encoded.
  static String pair(String serviceName) =>
      '/pair/${Uri.encodeComponent(serviceName)}';

  /// The premium screen, opened from [source] (for analytics).
  static String paywall({required PaywallSource source}) =>
      '$paywallPath?source=${source.name}';
}

/// The `name` of every [GoRoute]: parameter-free, so analytics can log a
/// screen without a path (Ruling P6-R6).
abstract final class AppRouteNames {
  /// First-run introduction.
  static const onboarding = 'onboarding';

  /// List of TVs found on the network.
  static const discover = 'discover';

  /// Pairing with a TV.
  static const pair = 'pair';

  /// The remote control.
  static const remote = 'remote';

  /// Apps on the TV.
  static const apps = 'apps';

  /// Edit apps.
  static const manageApps = 'manage_apps';

  /// Saved TVs.
  static const devices = 'devices';

  /// Edit page of a saved TV.
  static const editDevice = 'edit_device';

  /// The settings hub.
  static const settings = 'settings';

  /// Settings: theme and language.
  static const settingsAppearance = 'settings_appearance';

  /// Settings: touchpad or D-pad, and the row above it.
  static const settingsRemoteLayout = 'settings_remote_layout';

  /// Settings: haptics, Smooth Press, screen and keyboard.
  static const settingsRemoteBehaviour = 'settings_remote_behaviour';

  /// Settings: troubleshooting and common questions.
  static const settingsHelp = 'settings_help';

  /// Settings: version, licences and credits.
  static const settingsAbout = 'settings_about';

  /// Settings: usage statistics, crash reports and ads.
  static const settingsPrivacy = 'settings_privacy';

  /// The premium screen.
  static const paywall = 'paywall';

  /// Every route name.
  static const Set<String> all = {
    onboarding,
    discover,
    pair,
    remote,
    apps,
    manageApps,
    devices,
    editDevice,
    settings,
    settingsAppearance,
    settingsRemoteLayout,
    settingsRemoteBehaviour,
    settingsHelp,
    settingsAbout,
    settingsPrivacy,
    paywall,
  };
}

/// Picks the screen the app opens on.
///
/// A saved TV opens the remote; otherwise a first run opens onboarding and
/// everything else opens discovery. When reading the saved TVs fails, the
/// error goes to [onError] and the app carries on as if none were saved.
Future<String> resolveInitialLocation({
  required SettingsStore settings,
  required DeviceRepository devices,
  void Function(Object error, StackTrace stack)? onError,
}) async {
  try {
    if (await devices.lastUsed() != null) return AppRoutes.remote;
  } on Object catch (error, stack) {
    onError?.call(error, stack);
  }
  return settings.onboardingComplete
      ? AppRoutes.discover
      : AppRoutes.onboarding;
}

/// The route to open first. Bootstrap must override it with the result of
/// [resolveInitialLocation].
@Riverpod(keepAlive: true)
String initialLocation(Ref ref) => throw UnimplementedError(
  'initialLocationProvider must be overridden at bootstrap',
);

/// Reports each screen to analytics by its route name. It is built here, not
/// in `core/`, because the names are `AppRouteNames`.
@Riverpod(keepAlive: true)
AnalyticsRouteObserver analyticsRouteObserver(Ref ref) =>
    AnalyticsRouteObserver(
      screenNames: AppRouteNames.all,
      onScreen: ref.read(appAnalyticsProvider.notifier).screen,
    );

/// The page every route uses (Ruling P7-C2): a [MaterialPage], so the theme's
/// `AppPageTransitionsBuilder` applies (the platform transition, iOS edge
/// swipe-back, Android predictive back, none under reduce motion).
///
/// go_router 18.1.1 picks its own page type by looking for material_ui's
/// `MaterialApp`, not Flutter's, so a route with a plain `builder:` would get
/// a `NoTransitionPage`. It is a [MaterialPage] on iOS too: a `CupertinoPage`
/// would ignore the theme's page transitions and reduce motion.
Page<void> appPage(GoRouterState state, Widget child) => MaterialPage<void>(
  key: state.pageKey,
  name: state.name ?? state.path,
  arguments: <String, String>{
    ...state.pathParameters,
    ...state.uri.queryParameters,
  },
  restorationId: state.pageKey.value,
  child: child,
);

/// The app's router.
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final router = GoRouter(
    observers: [
      ref.watch(pageRouteObserverProvider),
      ref.watch(analyticsRouteObserverProvider),
    ],
    initialLocation: ref.watch(initialLocationProvider),
    routes: [
      GoRoute(
        name: AppRouteNames.onboarding,
        path: AppRoutes.onboarding,
        pageBuilder: (_, state) => appPage(state, const OnboardingScreen()),
      ),
      GoRoute(
        name: AppRouteNames.discover,
        path: AppRoutes.discover,
        pageBuilder: (_, state) => appPage(state, const DiscoveryScreen()),
      ),
      GoRoute(
        name: AppRouteNames.pair,
        path: '/pair/:serviceName',
        pageBuilder: (_, state) => appPage(
          state,
          PairingScreen(
            serviceName: state.pathParameters['serviceName']!,
            tv: state.extra is DiscoveredTv
                ? state.extra! as DiscoveredTv
                : null,
          ),
        ),
      ),
      GoRoute(
        name: AppRouteNames.remote,
        path: AppRoutes.remote,
        pageBuilder: (_, state) => appPage(state, const RemoteScreen()),
      ),
      GoRoute(
        name: AppRouteNames.apps,
        path: AppRoutes.apps,
        pageBuilder: (_, state) => appPage(state, const AppsScreen()),
        routes: [
          GoRoute(
            name: AppRouteNames.manageApps,
            path: 'manage',
            pageBuilder: (_, state) => appPage(state, const ManageAppsScreen()),
          ),
        ],
      ),
      GoRoute(
        name: AppRouteNames.devices,
        path: AppRoutes.devices,
        pageBuilder: (_, state) => appPage(state, const DevicesScreen()),
        routes: [
          GoRoute(
            name: AppRouteNames.editDevice,
            path: ':serviceName',
            pageBuilder: (_, state) => appPage(
              state,
              EditDeviceScreen(
                serviceName: state.pathParameters['serviceName']!,
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        name: AppRouteNames.settings,
        path: AppRoutes.settings,
        pageBuilder: (_, state) => appPage(
          state,
          SettingsScreen(
            fromSetup: state.uri.queryParameters['from'] == 'setup',
          ),
        ),
        routes: [
          GoRoute(
            name: AppRouteNames.settingsAppearance,
            path: 'appearance',
            pageBuilder: (_, state) => appPage(state, const AppearancePage()),
          ),
          GoRoute(
            name: AppRouteNames.settingsRemoteLayout,
            path: 'remote-layout',
            pageBuilder: (_, state) => appPage(state, const RemoteLayoutPage()),
          ),
          GoRoute(
            name: AppRouteNames.settingsRemoteBehaviour,
            path: 'remote-behaviour',
            pageBuilder: (_, state) =>
                appPage(state, const RemoteBehaviourPage()),
          ),
          GoRoute(
            name: AppRouteNames.settingsHelp,
            path: 'help',
            pageBuilder: (_, state) => appPage(state, const HelpPage()),
          ),
          GoRoute(
            name: AppRouteNames.settingsAbout,
            path: 'about',
            pageBuilder: (_, state) => appPage(state, const AboutPage()),
          ),
          GoRoute(
            name: AppRouteNames.settingsPrivacy,
            path: 'privacy',
            pageBuilder: (_, state) =>
                appPage(state, const PrivacyChoicesPage()),
          ),
        ],
      ),
      GoRoute(
        name: AppRouteNames.paywall,
        path: AppRoutes.paywallPath,
        pageBuilder: (_, state) => appPage(
          state,
          PaywallScreen(
            source: PaywallSource.parse(state.uri.queryParameters['source']),
          ),
        ),
      ),
    ],
    errorPageBuilder: (_, state) => appPage(
      state,
      Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return PlaceholderScreen(
            title: l10n.routeNotFoundTitle,
            body: l10n.routeNotFoundBody,
            actionLabel: l10n.routeNotFoundAction,
            onAction: () => context.go(AppRoutes.discover),
          );
        },
      ),
    ),
  );
  ref.onDispose(router.dispose);
  return router;
}
