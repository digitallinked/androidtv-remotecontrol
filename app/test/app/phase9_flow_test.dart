import 'dart:async';
import 'dart:io';

import 'package:atv_remote/atv_remote.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/app/flavor.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/widgets/app_dialog.dart';
import 'package:tv_remote/bootstrap.dart';
import 'package:tv_remote/core/ads/ad_unit_ids.dart';
import 'package:tv_remote/core/config/app_config.dart';
import 'package:tv_remote/core/config/service_config.dart';
import 'package:tv_remote/core/firebase/firebase_bootstrap.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/apps/data/catalogue_repository.dart';
import 'package:tv_remote/features/discovery/presentation/discovery_screen.dart';
import 'package:tv_remote/features/onboarding/presentation/onboarding_screen.dart';
import 'package:tv_remote/features/remote/presentation/remote_screen.dart';
import 'package:tv_remote/features/remote/presentation/widgets/quick_access_row.dart';

import '../../tool/release_check.dart';
import '../helpers/existing_database.dart';
import '../helpers/fake_ads_overrides.dart';
import '../helpers/fake_ads_sdk.dart';
import '../helpers/fake_config_source.dart';
import '../helpers/fake_remote_session.dart';
import '../helpers/gather_consent.dart';
import '../helpers/in_memory_device_repository.dart';
import '../helpers/platform_override.dart';
import '../helpers/pump_router_app.dart';
import '../helpers/recording_crash_reporter.dart';
import '../helpers/test_catalogue.dart';
import '../helpers/test_devices.dart';
import '../platform/no_dart_io_platform_test.dart' as dart_io_scan;
import '../release/placeholders_test.dart' as placeholders;
import '../tool/release_fixture.dart';

/// Seam tests for Phase 9: the fresh-database reset with onboarding, the
/// iOS explainer and the Apps row; the Remote Config kill switch across
/// launches; and the release checker against the native AdMob guards. The
/// last two re-run the Task 9.5 and 9.8 checks for the phase exit.
void main() {
  ProviderContainer containerOf(WidgetTester t) =>
      ProviderScope.containerOf(t.element(find.byType(MaterialApp)));

  void phone(WidgetTester t) {
    t.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  /// The test app's platform fakes, minus what bootstrap provides itself,
  /// with [overrides] in place of the defaults they replace.
  Future<List<Override>> platformFakes(List<Override> overrides) async {
    final unused = AppDatabase(NativeDatabase.memory());
    addTearDown(unused.close);
    final providedByBootstrap = {
      settingsStoreProvider,
      appDatabaseProvider,
      initialLocationProvider,
      flavorProvider,
      serviceConfigProvider,
      firebaseStatusProvider,
    };
    return mergeOverrides([
      for (final o in testAppOverrides(
        store: await SettingsStore.open(),
        db: unused,
        initialLocation: AppRoutes.discover,
      ))
        if (!providedByBootstrap.contains(o.origin)) o,
    ], overrides);
  }

  testWidgetsOn(
    TargetPlatform.iOS,
    'a_restored_iphone_gets_onboarding_the_explainer_and_the_default_row',
    (t) async {
      phone(t);
      // What an iCloud restore brings back without the database (Ruling
      // P9-R6): the old phone's three "done" flags.
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            'settings.onboarding_complete': true,
            'privacy.att_preprompt_shown': true,
            'apps.shortcuts_seeded': true,
          });
      final devices = InMemoryDeviceRepository();
      final session = FakeRemoteSession(
        initial: const TvConnectionState(status: ConnectionStatus.connected),
      );

      await t.pumpWidget(
        await buildRootWidget(
          flavor: Flavor.dev,
          crashReporter: RecordingCrashReporter(),
          // Created by this run, as on the restored phone.
          openDatabase: () => AppDatabase(NativeDatabase.memory()),
          overrides: await platformFakes([
            ...fakeAdsOverrides(),
            remoteConfigSourceProvider.overrideWithValue(FakeConfigSource({})),
            deviceRepositoryProvider.overrideWithValue(devices),
            savedDevicesProvider.overrideWith(
              (ref) => ref.watch(deviceRepositoryProvider).watchAll(),
            ),
            deviceRegionProvider.overrideWithValue('MY'),
            remoteSessionProvider.overrideWith((ref) async => session),
          ]),
        ),
      );
      await t.pumpAndSettle();

      // Onboarding again, then the Local Network explainer, then discovery.
      expect(find.byType(OnboardingScreen), findsOneWidget);
      // Get started is on the last of the three cards.
      for (var card = 1; card < 3; card++) {
        await t.tap(find.text('Next'));
        await t.pumpAndSettle();
      }
      await t.tap(find.text('Get started'));
      await t.pumpAndSettle();
      // The Local Network explainer by its own title, not any dialog.
      final strings = lookupAppLocalizations(const Locale('en'));
      expect(
        find.descendant(
          of: find.byType(AppDialog<void>),
          matching: find.text(strings.onboardingLocalNetworkTitle),
        ),
        findsOneWidget,
      );
      expect(find.text(strings.onboardingLocalNetworkBody), findsOneWidget);
      await t.tap(find.text('Continue'));
      await t.pumpAndSettle();
      expect(find.byType(DiscoveryScreen), findsOneWidget);
      final settings = containerOf(t).read(settingsStoreProvider);
      expect(settings.onboardingComplete, isTrue);

      // A TV is saved (as pairing does) and the remote opens: the Apps row
      // is the Malaysian default, because the restored "seeded" flag was
      // reset with the new database.
      await devices.upsert(savedTv());
      unawaited(containerOf(t).read(appRouterProvider).push(AppRoutes.remote));
      await t.pumpAndSettle();
      expect(find.byType(RemoteScreen), findsOneWidget);
      final row = t.widget<QuickAccessBar>(find.byType(QuickAccessBar));
      expect(
        [for (final app in row.apps) app.package],
        [
          for (final app in testCatalogue().defaultShortcutsFor('MY'))
            app.package,
        ],
      );
      expect(row.apps, isNotEmpty);
      expect(settings.shortcutsSeeded, isTrue);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('the_banner_kill_switch_applies_from_the_next_launch', (
    t,
  ) async {
    phone(t);
    // A relaunch of a set-up phone.
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
          'settings.onboarding_complete': true,
          'apps.shortcuts_seeded': true,
          'review.launch_count': 3,
        });
    // The banner is on now; the switch-off is fetched during launch 1.
    final source = FakeConfigSource(
      const {'ads_banner_enabled': true},
      fetched: const {'ads_banner_enabled': false},
    );
    final openDatabase = await existingDatabases();

    /// Starts the app with [sdk], then opens Apps and the Settings hub.
    Future<AppConfigValues> launch(FakeAdsSdk sdk) async {
      await t.pumpWidget(
        await buildRootWidget(
          flavor: Flavor.dev,
          crashReporter: RecordingCrashReporter(),
          openDatabase: openDatabase,
          overrides: await platformFakes([
            ...fakeAdsOverrides(sdk: sdk),
            remoteConfigSourceProvider.overrideWithValue(source),
            remoteSessionProvider.overrideWith(
              (ref) async => FakeRemoteSession(
                initial: const TvConnectionState(
                  status: ConnectionStatus.connected,
                ),
              ),
            ),
            savedDevicesProvider.overrideWith(
              (ref) => Stream.value(const <SavedDevice>[]),
            ),
          ]),
        ),
      );
      await t.pumpAndSettle();
      await gatherConsent(t);
      final router = containerOf(t).read(appRouterProvider);
      unawaited(router.push(AppRoutes.apps));
      await t.pumpAndSettle();
      router.pop();
      await t.pumpAndSettle();
      unawaited(router.push(AppRoutes.settings));
      await t.pumpAndSettle();
      return containerOf(t).read(appConfigProvider);
    }

    // Launch 1: the fetched "off" isn't active yet, so the banner is asked
    // for (the fake never fills it: the slot stays loading).
    final first = FakeAdsSdk();
    final config1 = await launch(first);
    expect(config1.adsBannerEnabled, isTrue);
    expect(first.bannerLoads, greaterThan(0));
    expect(source.values['ads_banner_enabled'], isFalse);

    // Launch 2, same source: the switch is active, and no banner is asked
    // for on Apps or on the Settings hub.
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
    final second = FakeAdsSdk();
    final config2 = await launch(second);
    expect(config2.adsBannerEnabled, isFalse);
    expect(second.bannerLoads, 0);
    expect(second.bannerSizeCalls, 0);

    // Interstitials were never switched on.
    expect(config1.adsInterstitialEnabled, isFalse);
    expect(config2.adsInterstitialEnabled, isFalse);
    expect(first.interstitialLoads + second.interstitialLoads, 0);
    expect(t.takeException(), isNull);
  });

  test(
    'the_release_check_and_the_native_guards_agree_on_the_admob_rules',
    () async {
      final gradle = File(
        'android/app/build.gradle.kts',
      ).readAsStringSync().replaceAll('\r\n', '\n');
      String gradleValue(String name) => RegExp(
        'val $name = "([^"]+)"',
      ).firstMatch(gradle)!.group(1)!;

      // Android: the id build.gradle.kts falls back to, and refuses for the
      // upload bundle, is Google's test app id ...
      final androidTestId = gradleValue('admobTestAppId');
      expect(androidTestId, AdMobTestIds.androidAppId);
      expect(
        androidTestId.startsWith(gradleValue('admobTestPublisherPrefix')),
        isTrue,
        reason: 'the bundle refusal (prodUsesTestAdmobId) catches it',
      );
      // ... and the release check refuses the same value.
      Future<List<String>> codes(
        ReleasePlatform platform,
        Map<String, String> files,
      ) async => [
        for (final r in await checkRelease(
          root: await writeReleaseFixture(files: files, gitInit: false),
          platform: platform,
          listTrackedFiles: (_) async => const <String>[],
        ))
          r.code,
      ];
      expect(
        await codes(ReleasePlatform.android, {
          FixturePaths.secretsProperties: fixtureSecretsProperties(
            admobAppIdProd: androidTestId,
          ),
        }),
        ['admob-app-android'],
      );
      expect(await codes(ReleasePlatform.android, const {}), isEmpty);

      // iOS: the test id the xcconfigs fall back to ...
      final xcconfig = File('ios/Flutter/Release.xcconfig').readAsStringSync();
      final iosTestId = RegExp(
        r'ADMOB_APP_ID_PROD = (\S+)',
      ).firstMatch(xcconfig)!.group(1)!;
      expect(iosTestId, AdMobTestIds.iosAppId);
      // ... is refused by the release check ...
      expect(
        await codes(ReleasePlatform.ios, {
          FixturePaths.secretsXcconfig: fixtureSecretsXcconfig(
            admobAppIdProd: iosTestId,
          ),
        }),
        ['admob-app-ios'],
      );
      expect(await codes(ReleasePlatform.ios, const {}), isEmpty);

      // ... and by the Xcode build phase on an archive (ACTION=install).
      final shell = _posixShell();
      if (shell == null) {
        markTestSkipped('sh is not on the PATH');
        return;
      }
      Future<ProcessResult> guard(String id) => runTool(
        shell,
        ['ios/scripts/check_admob_app_id.sh'],
        environment: {
          'CONFIGURATION': 'Release-prod',
          'ACTION': 'install',
          'ADMOB_APP_ID': id,
        },
      );
      final refused = await guard(iosTestId);
      expect(refused.exitCode, 1, reason: '${refused.stdout}');
      expect(refused.stdout, contains("Google's test AdMob app id"));
      final allowed = await guard(fakeAdmobAppId);
      expect(allowed.exitCode, 0, reason: '${allowed.stdout}');
    },
  );

  test('no_app_lib_file_uses_dart_io_platform', () {
    expect(dart_io_scan.appLibDartIoPlatformOffenders(), isEmpty);
  });

  test('every_release_doc_token_is_registered', () {
    final keys = placeholders.loadPlaceholders().keys.toSet();
    final docs = placeholders.releaseDocs();
    expect(docs, isNotEmpty);
    final offenders = [
      for (final doc in docs)
        for (final m in placeholders.anyToken.allMatches(
          doc.readAsStringSync(),
        ))
          if (!keys.contains(m[1])) '${doc.path}: {{${m[1]}}}',
    ];
    expect(offenders, isEmpty);
  });
}

/// A POSIX shell: Git Bash's launcher on Windows (it puts its own `grep`
/// on PATH), `sh` elsewhere if it runs. `null` when there is none, and the
/// caller skips with `markTestSkipped('sh is not on the PATH')`.
String? _posixShell() {
  if (!Platform.isWindows) {
    try {
      Process.runSync('sh', const ['-c', 'exit 0']);
      return 'sh';
    } on ProcessException {
      return null;
    }
  }
  final env = Platform.environment;
  for (final base in [
    env['ProgramFiles'],
    env['ProgramW6432'],
    if (env['LOCALAPPDATA'] != null) '${env['LOCALAPPDATA']}\\Programs',
  ]) {
    if (base == null) continue;
    final candidate = '$base\\Git\\bin\\bash.exe';
    if (File(candidate).existsSync()) return candidate;
  }
  return null;
}
