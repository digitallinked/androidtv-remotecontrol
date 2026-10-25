import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/theme/app_theme.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';

/// Pumps the real router app at [initialLocation] and returns the settings
/// store it runs on (backed by in-memory preferences and an in-memory
/// database that is closed when the test ends).
///
/// Every call gets a fresh `ProviderScope`, so several locations can be
/// pumped in one test without reusing a router. [overrides] are applied after
/// the defaults.
Future<SettingsStore> pumpRouterApp(
  WidgetTester tester, {
  required String initialLocation,
  List<Override> overrides = const [],
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) async {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  final store = await SettingsStore.open();
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        settingsStoreProvider.overrideWithValue(store),
        appDatabaseProvider.overrideWithValue(db),
        initialLocationProvider.overrideWithValue(initialLocation),
        ...overrides,
      ],
      child: Consumer(
        builder: (_, ref, _) => MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(brightness: brightness),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, app) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: app!,
          ),
          routerConfig: ref.watch(appRouterProvider),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}
