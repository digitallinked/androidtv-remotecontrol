import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/app/app.dart';
import 'package:tv_remote/app/app_shell.dart';
import 'package:tv_remote/app/flavor.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/theme/colour_styles.dart';
import 'package:tv_remote/core/ads/ads_service.dart';
import 'package:tv_remote/core/ads/consent_service.dart';
import 'package:tv_remote/core/ads/tracking_service.dart';
import 'package:tv_remote/core/app_info/app_info.dart';
import 'package:tv_remote/core/config/service_config.dart';
import 'package:tv_remote/core/device/screen_services.dart';
import 'package:tv_remote/core/firebase/firebase_bootstrap.dart';
import 'package:tv_remote/core/haptics/haptics.dart';
import 'package:tv_remote/core/links/link_opener.dart';
import 'package:tv_remote/core/purchases/premium.dart';
import 'package:tv_remote/core/review/review_prompter.dart';
import 'package:tv_remote/core/session/remote_client_factory.dart';
import 'package:tv_remote/core/session/session_signals.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/settings_controller.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/core/wake/wake_on_lan_service.dart';
import 'package:tv_remote/features/apps/data/apps_data_providers.dart';
import 'package:tv_remote/features/apps/data/catalogue_repository.dart';
import 'package:tv_remote/features/discovery/data/discovery_providers.dart';
import 'package:tv_remote/features/pairing/data/pairing_providers.dart';

import 'fake_ads_sdk.dart';
import 'fake_consent_service.dart';
import 'fake_pairing_client.dart';
import 'fake_remote_client.dart';
import 'fake_review_requester.dart';
import 'fake_screen_services.dart';
import 'fake_tracking_service.dart';
import 'fake_tv_discovery.dart';
import 'fake_wake_on_lan.dart';
import 'in_memory_app_usage_repository.dart';
import 'in_memory_shortcut_repository.dart';
import 'manual_session_signals.dart';
import 'recording_haptics.dart';
import 'recording_link_opener.dart';
import 'test_catalogue.dart';
import 'test_identity.dart';

/// Pumps the real router app at [initialLocation] and returns the settings
/// store it runs on (backed by in-memory preferences and an in-memory
/// database that is closed when the test ends).
///
/// Pass [database] to run on a database of your own (for example one that
/// already holds saved TVs); the caller closes it. The defaults also replace
/// everything platform-backed: the client identity (a fixture), the remote
/// clients (fakes that connect at once) and the host resolver (finds
/// nothing).
///
/// Every call gets a fresh `ProviderScope`, so several locations can be
/// pumped in one test without reusing a router. [overrides] are applied after
/// the defaults: an override of a provider that has a default replaces it.
///
/// [prepareSettings] runs after the store has opened and before the app is
/// pumped, to write the settings a test starts with. [accessibleNavigation]
/// turns on the screen-reader flag of the `MediaQuery` that [textScale] is
/// applied in.
///
/// [textScaler] replaces the linear [textScale] with a scaler of your own, for
/// the non-linear curves of Android 14+. [disableAnimations] turns on reduce
/// motion in that same `MediaQuery`.
///
/// The theme follows the stored colour style and Premium exactly as `App`
/// does; [brightness] stands in for the system theme. [dynamicScheme] stands
/// in for the phone's wallpaper colours and applies while the "Colours from
/// wallpaper" setting is on.
///
/// With [settle] false it pumps one frame instead of waiting for the app to
/// go idle: a screen with a running progress indicator never goes idle, and
/// `pumpAndSettle` would then run the fake clock forward until the screen
/// changes.
Future<SettingsStore> pumpRouterApp(
  WidgetTester tester, {
  required String initialLocation,
  AppDatabase? database,
  List<Override> overrides = const [],
  Brightness brightness = Brightness.light,
  double textScale = 1,
  TextScaler? textScaler,
  bool settle = true,
  Future<void> Function(SettingsStore store)? prepareSettings,
  bool accessibleNavigation = false,
  bool disableAnimations = false,
  ColorScheme? dynamicScheme,
}) async {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  final store = await SettingsStore.open();
  if (prepareSettings != null) await prepareSettings(store);
  final db = database ?? AppDatabase(NativeDatabase.memory());
  if (database == null) addTearDown(db.close);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: _withDefaults(
        _defaults(store: store, db: db, initialLocation: initialLocation),
        overrides,
      ),
      child: Consumer(
        builder: (_, ref, _) => MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: buildSettingsTheme(
            brightness: brightness,
            settings: ref.watch(settingsControllerProvider),
            premium: ref.watch(premiumProvider),
            dynamicScheme: ref.watch(settingsControllerProvider).dynamicColor
                ? dynamicScheme
                : null,
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, app) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: textScaler ?? TextScaler.linear(textScale),
              accessibleNavigation: accessibleNavigation,
              // Keeps a platform-level flag a test may have set.
              disableAnimations:
                  disableAnimations || MediaQuery.disableAnimationsOf(context),
            ),
            child: buildAppShell(context, app),
          ),
          routerConfig: ref.watch(appRouterProvider),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return store;
}

/// Pumps the app's own [App] widget at [initialLocation], with the same
/// defaults as [pumpRouterApp], and returns the settings store it runs on.
///
/// Use it where the wiring of `App` itself is under test: it starts the
/// analytics hooks, the silent consent update, the interstitial pacing and
/// the review prompter the way a launch does, and themes the app the way a
/// launch does. It takes no text scale or brightness: the app follows the
/// test's platform dispatcher.
Future<SettingsStore> pumpRealApp(
  WidgetTester tester, {
  required String initialLocation,
  AppDatabase? database,
  List<Override> overrides = const [],
  bool settle = true,
  Future<void> Function(SettingsStore store)? prepareSettings,
}) async {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  final store = await SettingsStore.open();
  if (prepareSettings != null) await prepareSettings(store);
  final db = database ?? AppDatabase(NativeDatabase.memory());
  if (database == null) addTearDown(db.close);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: _withDefaults(
        _defaults(store: store, db: db, initialLocation: initialLocation),
        overrides,
      ),
      child: const App(),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return store;
}

/// The overrides every pumped app starts with; see [pumpRouterApp].
List<Override> _defaults({
  required SettingsStore store,
  required AppDatabase db,
  required String initialLocation,
}) => [
  settingsStoreProvider.overrideWithValue(store),
  appDatabaseProvider.overrideWithValue(db),
  identityStoreProvider.overrideWithValue(testIdentityStore()),
  remoteClientFactoryProvider.overrideWithValue(
    FakeRemoteClients().create,
  ),
  pairingClientFactoryProvider.overrideWithValue(
    FakePairingClients().create,
  ),
  hostResolverProvider.overrideWithValue((_) async => null),
  sessionSignalsProvider.overrideWithValue(ManualSessionSignals()),
  hapticsProvider.overrideWithValue(RecordingHaptics()),
  screenWakeLockProvider.overrideWithValue(RecordingWakeLock()),
  screenDimmerProvider.overrideWithValue(RecordingDimmer()),
  wakeOnLanServiceProvider.overrideWithValue(FakeWakeOnLan()),
  wakeOnLanAvailableProvider.overrideWithValue(true),
  // Shortcuts and usage live in memory (drift's own streams leave
  // timers behind); the catalogue is the real bundled file, and no
  // region means the "*" default row.
  shortcutRepositoryProvider.overrideWithValue(
    InMemoryShortcutRepository(),
  ),
  appUsageRepositoryProvider.overrideWithValue(
    InMemoryAppUsageRepository(),
  ),
  catalogueProvider.overrideWith((ref) async => testCatalogue()),
  deviceRegionProvider.overrideWithValue(null),
  // What the About page and the legal links read: a flavor, the
  // platform's package info and the url_launcher plugin.
  flavorProvider.overrideWithValue(Flavor.dev),
  appInfoProvider.overrideWith(
    (ref) async => const AppInfo(
      appName: 'Remotely Dev',
      version: '1.0.0',
      buildNumber: '1',
      os: 'Android',
      osVersion: '12',
    ),
  ),
  linkOpenerProvider.overrideWithValue(RecordingLinkOpener()),
  // No services are configured in tests: Firebase is not started.
  serviceConfigProvider.overrideWithValue(ServiceConfig.none),
  firebaseStatusProvider.overrideWithValue(FirebaseStatus.notConfigured),
  // Consent: a region that needs none, no form, ads allowed. Tracking:
  // the Android answer (nothing to decide).
  consentServiceProvider.overrideWithValue(FakeConsentService()),
  trackingServiceProvider.overrideWithValue(FakeTrackingService()),
  // The ads SDK starts but never loads, so every screen shows the
  // zero-size banner slot of Phase 5; a test of ads passes
  // `FakeAdsSdk(loads: true)`.
  adsSdkProvider.overrideWithValue(FakeAdsSdk()),
  // The store's review API is there and records the requests.
  reviewRequesterProvider.overrideWithValue(FakeReviewRequester()),
  // Premium is the real notifier. No RevenueCat key is set, so the
  // purchase service is the unavailable one (free, known at once);
  // tests override `purchaseServiceProvider` or `premiumProvider`.
  initialLocationProvider.overrideWithValue(initialLocation),
  tvDiscoveryFactoryProvider.overrideWithValue(
    FakeTvDiscoveries().create,
  ),
  // The database's own stream leaves a timer behind when it is
  // disposed, which fails the test.
  savedDevicesProvider.overrideWith(
    (ref) => Stream.value(const <SavedDevice>[]),
  ),
];

/// [defaults] followed by [overrides]; an override replaces the default of the
/// same provider, because a container rejects two overrides of one provider.
List<Override> _withDefaults(
  List<Override> defaults,
  List<Override> overrides,
) {
  final replaced = {for (final o in overrides) o.origin};
  return [
    for (final o in defaults)
      if (!replaced.contains(o.origin)) o,
    ...overrides,
  ];
}
