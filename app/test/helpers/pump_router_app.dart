import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/app/app_shell.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/theme/app_theme.dart';
import 'package:tv_remote/core/haptics/haptics.dart';
import 'package:tv_remote/core/session/remote_client_factory.dart';
import 'package:tv_remote/core/session/session_signals.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/core/wake/wake_on_lan_service.dart';
import 'package:tv_remote/features/discovery/data/discovery_providers.dart';
import 'package:tv_remote/features/pairing/data/pairing_providers.dart';

import 'fake_pairing_client.dart';
import 'fake_remote_client.dart';
import 'fake_tv_discovery.dart';
import 'fake_wake_on_lan.dart';
import 'manual_session_signals.dart';
import 'recording_haptics.dart';
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
  bool settle = true,
  Future<void> Function(SettingsStore store)? prepareSettings,
  bool accessibleNavigation = false,
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
      overrides: _withDefaults([
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
        wakeOnLanServiceProvider.overrideWithValue(FakeWakeOnLan()),
        wakeOnLanAvailableProvider.overrideWithValue(true),
        initialLocationProvider.overrideWithValue(initialLocation),
        tvDiscoveryFactoryProvider.overrideWithValue(
          FakeTvDiscoveries().create,
        ),
        // The database's own stream leaves a timer behind when it is
        // disposed, which fails the test.
        savedDevicesProvider.overrideWith(
          (ref) => Stream.value(const <SavedDevice>[]),
        ),
      ], overrides),
      child: Consumer(
        builder: (_, ref, _) => MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(brightness: brightness),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, app) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              accessibleNavigation: accessibleNavigation,
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
