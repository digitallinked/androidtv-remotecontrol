import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/widgets/placeholder_screen.dart';
import 'package:tv_remote/core/storage/device_repository.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/features/discovery/presentation/discovery_screen.dart';
import 'package:tv_remote/features/onboarding/presentation/onboarding_screen.dart';

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

  /// Saved TVs.
  static const devices = '/devices';

  /// App settings.
  static const settings = '/settings';

  /// Path of the premium screen, without its query.
  static const paywallPath = '/paywall';

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
        builder: (context, state) => PlaceholderScreen(
          title: AppLocalizations.of(context).pageTitlePair,
          params: {'serviceName': state.pathParameters['serviceName']!},
          extra: state.extra,
        ),
      ),
      GoRoute(
        path: AppRoutes.remote,
        builder: (context, _) => PlaceholderScreen(
          title: AppLocalizations.of(context).pageTitleRemote,
        ),
      ),
      GoRoute(
        path: AppRoutes.apps,
        builder: (context, _) => PlaceholderScreen(
          title: AppLocalizations.of(context).pageTitleApps,
        ),
      ),
      GoRoute(
        path: AppRoutes.devices,
        builder: (context, _) => PlaceholderScreen(
          title: AppLocalizations.of(context).pageTitleDevices,
        ),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, _) => PlaceholderScreen(
          title: AppLocalizations.of(context).pageTitleSettings,
        ),
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
