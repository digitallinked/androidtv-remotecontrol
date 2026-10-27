import 'package:atv_remote/atv_remote.dart' show DiscoveredTv;
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/widgets/placeholder_screen.dart';
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
import 'package:tv_remote/features/remote/presentation/remote_screen.dart';
import 'package:tv_remote/features/settings/presentation/about_page.dart';
import 'package:tv_remote/features/settings/presentation/appearance_page.dart';
import 'package:tv_remote/features/settings/presentation/help_page.dart';
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

  /// Path of the premium screen, without its query.
  static const paywallPath = '/paywall';

  /// Edit page of the saved TV [serviceName]; the name is percent-encoded.
  static String editDevice(String serviceName) =>
      '/devices/${Uri.encodeComponent(serviceName)}';

  /// Pairing with the TV named [serviceName]. The name is percent-encoded.
  static String pair(String serviceName) =>
      '/pair/${Uri.encodeComponent(serviceName)}';

  /// The premium screen, opened from [source] (for analytics).
  static String paywall({required String source}) =>
      Uri(path: paywallPath, queryParameters: {'source': source}).toString();
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

/// The app's router.
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final router = GoRouter(
    observers: [ref.watch(pageRouteObserverProvider)],
    initialLocation: ref.watch(initialLocationProvider),
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.discover,
        builder: (_, _) => const DiscoveryScreen(),
      ),
      GoRoute(
        path: '/pair/:serviceName',
        builder: (_, state) => PairingScreen(
          serviceName: state.pathParameters['serviceName']!,
          tv: state.extra is DiscoveredTv ? state.extra! as DiscoveredTv : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.remote,
        builder: (_, _) => const RemoteScreen(),
      ),
      GoRoute(
        path: AppRoutes.apps,
        builder: (_, _) => const AppsScreen(),
        routes: [
          GoRoute(
            path: 'manage',
            builder: (_, _) => const ManageAppsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.devices,
        builder: (_, _) => const DevicesScreen(),
        routes: [
          GoRoute(
            path: ':serviceName',
            builder: (_, state) => EditDeviceScreen(
              serviceName: state.pathParameters['serviceName']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, _) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'appearance',
            builder: (_, _) => const AppearancePage(),
          ),
          GoRoute(
            path: 'remote-layout',
            builder: (_, _) => const RemoteLayoutPage(),
          ),
          GoRoute(
            path: 'remote-behaviour',
            builder: (_, _) => const RemoteBehaviourPage(),
          ),
          GoRoute(path: 'help', builder: (_, _) => const HelpPage()),
          GoRoute(path: 'about', builder: (_, _) => const AboutPage()),
        ],
      ),
      GoRoute(
        path: AppRoutes.paywallPath,
        builder: (context, state) {
          final source = state.uri.queryParameters['source'];
          return PlaceholderScreen(
            title: AppLocalizations.of(context).pageTitlePaywall,
            params: {'source': ?source},
          );
        },
      ),
    ],
    errorBuilder: (context, _) {
      final l10n = AppLocalizations.of(context);
      return PlaceholderScreen(
        title: l10n.routeNotFoundTitle,
        body: l10n.routeNotFoundBody,
        actionLabel: l10n.routeNotFoundAction,
        onAction: () => context.go(AppRoutes.discover),
      );
    },
  );
  ref.onDispose(router.dispose);
  return router;
}
