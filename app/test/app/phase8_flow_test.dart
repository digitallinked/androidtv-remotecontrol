import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:atv_remote/atv_remote.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'package:tv_remote/core/analytics/app_analytics.dart';
import 'package:tv_remote/core/config/app_config.dart';
import 'package:tv_remote/core/config/service_config.dart';
import 'package:tv_remote/core/crash/crash_collection.dart';
import 'package:tv_remote/core/crash/crash_reporter.dart';
import 'package:tv_remote/core/firebase/firebase_bootstrap.dart';
import 'package:tv_remote/core/purchases/purchase_service.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/session/session_signals.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/core/tv/saved_device_x.dart';
import 'package:tv_remote/features/apps/data/apps_data_providers.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';
import 'package:tv_remote/features/discovery/data/discovery_providers.dart';
import 'package:tv_remote/features/onboarding/presentation/onboarding_screen.dart';
import 'package:tv_remote/features/pairing/data/pairing_providers.dart';
import 'package:tv_remote/features/pairing/presentation/widgets/pairing_code_field.dart';
import 'package:tv_remote/features/paywall/domain/paywall_source.dart';
import 'package:tv_remote/features/remote/presentation/remote_screen.dart';
import 'package:tv_remote/features/settings/presentation/help_page.dart';

import '../helpers/a11y.dart';
import '../helpers/fake_ads_overrides.dart';
import '../helpers/fake_config_source.dart';
import '../helpers/fake_pairing_client.dart';
import '../helpers/fake_purchase_service.dart';
import '../helpers/fake_remote_session.dart';
import '../helpers/fake_tv_discovery.dart';
import '../helpers/fake_tv_harness.dart';
import '../helpers/in_memory_device_repository.dart';
import '../helpers/in_memory_shortcut_repository.dart';
import '../helpers/manual_session_signals.dart';
import '../helpers/nonlinear_text_scaler.dart';
import '../helpers/pump_router_app.dart';
import '../helpers/pump_until.dart';
import '../helpers/recording_analytics_sink.dart';
import '../helpers/recording_crash_reporter.dart';
import '../helpers/recording_crashlytics_sink.dart';
import '../helpers/test_devices.dart';

/// Seam tests for Phase 8, in English and in Malay: the real router,
/// screens and providers, with the review-focus guarantees checked end to
/// end — backup off and the privacy copy that promises it, no TV data in
/// analytics or crash reports, the fake TV over real TLS, no leaked socket
/// across resumes, reduce motion, and the accessibility guidelines on every
/// route.
const List<Locale> _languages = [Locale('en'), Locale('ms')];

const String _tvName = 'Living Room TV 3';

/// The strings of [locale], outside any widget tree.
AppLocalizations _strings(Locale locale) => lookupAppLocalizations(locale);

/// The strings of the locale on show.
AppLocalizations _l(WidgetTester t) => AppLocalizations.of(
  t.element(
    find
        .descendant(
          of: find.byType(Localizations).first,
          matching: find.byType(Directionality),
        )
        .first,
  ),
);

void _phone(WidgetTester t, [Size size = const Size(390, 844)]) {
  t.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

ProviderContainer _containerOf(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(MaterialApp)));

/// Every string value in [value], a map, list or scalar, as text.
Iterable<String> _texts(Object? value) sync* {
  if (value is Map) {
    for (final entry in value.entries) {
      yield* _texts(entry.key);
      yield* _texts(entry.value);
    }
  } else if (value is Iterable) {
    for (final item in value) {
      yield* _texts(item);
    }
  } else if (value != null) {
    yield value.toString();
  }
}

/// Nothing the analytics [sink] received names [tvData]: no event name,
/// parameter or screen.
void _expectNoTvDataIn(
  RecordingAnalyticsSink sink,
  List<String> tvData, {
  required String why,
}) {
  final sent = [
    for (final e in sink.events) ...[e.name, ..._texts(e.params)],
    ...sink.screens,
  ];
  for (final data in tvData) {
    expect(
      sent.where((s) => s.contains(data)),
      isEmpty,
      reason: '$why: analytics carried "$data"',
    );
  }
  for (final screen in sink.screens) {
    expect(AppRouteNames.all, contains(screen), reason: why);
  }
}

/// A shortcut store whose table can't be read: the error names the TV, as a
/// database error can quote the row it failed on. It is an [Exception], so
/// Riverpod's default retry would re-run it behind a spinner (Ruling
/// P8-R10).
class _UnreadableShortcuts extends InMemoryShortcutRepository {
  _UnreadableShortcuts(this.error);

  final Exception error;

  @override
  Stream<List<AppEntry>> watchAll() => Stream.error(error);
}

class _DiskError implements Exception {
  const _DiskError(this.message);

  final String message;

  @override
  String toString() => 'SqliteException: $message';
}

/// Whether [paragraph] cuts its text: it ran past its lines, or is wider
/// than its box on one line, or taller than its box.
bool _truncated(RenderParagraph paragraph) {
  final width = paragraph.size.width;
  return paragraph.didExceedMaxLines ||
      (!paragraph.softWrap &&
          paragraph.getMaxIntrinsicWidth(double.infinity) > width + 0.5) ||
      paragraph.getMaxIntrinsicHeight(width) > paragraph.size.height + 0.5;
}

/// The field text [text] is on show, whole: not cut, not clipped.
Future<void> _expectWhole(WidgetTester t, String text, String why) async {
  final finder = find.text(text);
  expect(finder, findsOneWidget, reason: '$why: "$text" is on show');
  await t.ensureVisible(finder);
  await t.pump();
  final paragraph = t.renderObject<RenderParagraph>(finder);
  expect(_truncated(paragraph), isFalse, reason: '$why: "$text" is cut');
  expectNoClipping(t, reason: why);
}

/// Pumps [route] as [locale], with a saved TV in the repository the pages
/// read unless [withSavedTv] is false.
Future<SettingsStore> _pump(
  WidgetTester t,
  Locale locale,
  String route, {
  List<Override> overrides = const [],
  bool settle = true,
  bool withSavedTv = true,
  double textScale = 1,
  TextScaler? textScaler,
  Brightness brightness = Brightness.light,
  bool disableAnimations = false,
}) => pumpRouterApp(
  t,
  initialLocation: route,
  locale: locale,
  settle: settle,
  textScale: textScale,
  textScaler: textScaler,
  brightness: brightness,
  disableAnimations: disableAnimations,
  overrides: [
    if (withSavedTv) ...[
      deviceRepositoryProvider.overrideWithValue(
        InMemoryDeviceRepository([savedTv()]),
      ),
      savedDevicesProvider.overrideWith(
        (ref) => ref.watch(deviceRepositoryProvider).watchAll(),
      ),
    ],
    ...overrides,
  ],
);

/// Opens pairing as discovery does, pushed over the TV list. It does not
/// settle: the countdown never stops.
Future<void> _openPairing(
  WidgetTester t,
  Locale locale, {
  double textScale = 1,
  TextScaler? textScaler,
  Brightness brightness = Brightness.light,
}) async {
  await _pump(
    t,
    locale,
    AppRoutes.discover,
    settle: false,
    textScale: textScale,
    textScaler: textScaler,
    brightness: brightness,
    overrides: [
      pairingClientFactoryProvider.overrideWithValue(
        FakePairingClients().create,
      ),
    ],
  );
  final target = tv(_tvName);
  unawaited(
    _containerOf(
          t,
        )
        .read(appRouterProvider)
        .push(AppRoutes.pair(target.serviceName), extra: target),
  );
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
}

/// How to open each named route as a user meets it, in any language.
final Map<String, Future<void> Function(WidgetTester t, Locale locale)>
_routes = {
  AppRouteNames.onboarding: (t, l) => _pump(t, l, AppRoutes.onboarding),
  AppRouteNames.discover: (t, l) async {
    final discoveries = FakeTvDiscoveries();
    await _pump(
      t,
      l,
      AppRoutes.discover,
      settle: false,
      overrides: [
        tvDiscoveryFactoryProvider.overrideWithValue(discoveries.create),
      ],
    );
    discoveries.created.last.emit([tv(_tvName)]);
    await t.pump();
  },
  AppRouteNames.pair: _openPairing,
  AppRouteNames.remote: (t, l) async {
    final device = savedTv();
    final fake = FakeRemoteSession(
      pairingTarget: device.toDiscoveredTv(),
      initial: const TvConnectionState(status: ConnectionStatus.connected),
    )..push(const VolumeChanged(12, 40, false));
    await _pump(
      t,
      l,
      AppRoutes.remote,
      overrides: [remoteSessionProvider.overrideWith((ref) async => fake)],
    );
  },
  AppRouteNames.apps: (t, l) => _pump(t, l, AppRoutes.apps),
  AppRouteNames.manageApps: (t, l) => _pump(t, l, AppRoutes.manageApps),
  AppRouteNames.devices: (t, l) => _pump(t, l, AppRoutes.devices),
  AppRouteNames.editDevice: (t, l) =>
      _pump(t, l, AppRoutes.editDevice(_tvName)),
  AppRouteNames.settings: (t, l) => _pump(t, l, AppRoutes.settings),
  AppRouteNames.settingsAppearance: (t, l) =>
      _pump(t, l, AppRoutes.settingsAppearance),
  AppRouteNames.settingsRemoteLayout: (t, l) =>
      _pump(t, l, AppRoutes.settingsRemoteLayout),
  AppRouteNames.settingsRemoteBehaviour: (t, l) =>
      _pump(t, l, AppRoutes.settingsRemoteBehaviour),
  AppRouteNames.settingsHelp: (t, l) => _pump(t, l, AppRoutes.settingsHelp),
  AppRouteNames.settingsAbout: (t, l) => _pump(t, l, AppRoutes.settingsAbout),
  AppRouteNames.settingsPrivacy: (t, l) =>
      _pump(t, l, AppRoutes.settingsPrivacy),
  AppRouteNames.paywall: (t, l) => _pump(
    t,
    l,
    AppRoutes.paywall(source: PaywallSource.settings),
    overrides: [
      purchaseServiceProvider.overrideWithValue(
        FakePurchaseService(offer: testOffer()),
      ),
    ],
  ),
};

/// The `<application>` tag of the Android manifest, on one line.
String _applicationTag() {
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');
  return RegExp('<application [^>]*>').firstMatch(manifest)!.group(0)!;
}

Map<String, dynamic> _arb(String language) =>
    jsonDecode(
          File('lib/app/l10n/app_$language.arb').readAsStringSync(),
        )
        as Map<String, dynamic>;

void main() {
  testWidgets('malay_user_runs_onboarding_to_the_demo_remote', (t) async {
    _phone(t);
    final sink = RecordingAnalyticsSink();
    final ms = _strings(const Locale('ms'));
    await withSemantics(t, () async {
      await pumpRealApp(
        t,
        initialLocation: AppRoutes.onboarding,
        prepareSettings: (store) => store.setLocaleCode('ms'),
        overrides: [
          analyticsSinkProvider.overrideWithValue(sink),
          analyticsDebugBuildProvider.overrideWithValue(true),
        ],
      );
      expect(find.byType(OnboardingScreen), findsOneWidget);
      // The Malay copy, not English.
      expect(find.text('Cari TV anda'), findsOneWidget);
      expect(find.text(ms.onboardingConnectTitle), findsOneWidget);
      expect(find.text('Find your TV'), findsNothing);

      await t.tap(find.text('Cuba demo'));
      await t.pump();
      // The demo TV connects after 600 ms.
      await t.pump(const Duration(milliseconds: 700));
      await t.pumpAndSettle();
      expect(find.byType(RemoteScreen), findsOneWidget);
      expect(find.text(ms.demoBadgeLabel), findsOneWidget);
      expect(find.text('Disambungkan'), findsOneWidget);
      expect(find.textContaining(ms.tvPreviewVolume(8, 20)), findsOneWidget);

      await t.tap(find.bySemanticsLabel(ms.keyVolumeUp));
      await t.pump();
      expect(find.textContaining(ms.tvPreviewVolume(9, 20)), findsOneWidget);
      expect(find.text(ms.tvPreviewPressed(ms.keyVolumeUp)), findsOneWidget);
      await t.pumpAndSettle();

      await t.tap(find.byTooltip(ms.pageTitleSettings));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('Bantuan'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await t.tap(find.text('Bantuan'));
      await t.pumpAndSettle();
      expect(find.byType(HelpPage), findsOneWidget);

      final question = find.text(ms.faqNewPhoneQ);
      // The FAQ is built whole; bring the last question into view.
      await t.ensureVisible(question);
      await t.pumpAndSettle();
      await t.tap(question);
      await t.pumpAndSettle();
      await t.ensureVisible(find.text(ms.faqNewPhoneA));
      expect(find.text(ms.faqNewPhoneA), findsOneWidget);
      expect(ms.faqNewPhoneA, contains('tidak disalin dalam sandaran'));
      expect(t.takeException(), isNull);
    });
    expect(
      sink.eventNames.where((e) => e == 'onboarding_complete'),
      hasLength(1),
    );
    _expectNoTvDataIn(sink, [ms.demoTvName], why: 'malay demo');
  });

  for (final locale in _languages) {
    final code = locale.languageCode;

    testWidgets('a_storage_error_at_startup_is_scrubbed_and_shown_$code', (
      t,
    ) async {
      _phone(t);
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final l = _strings(locale);
      // The saved list is readable, so it seeds the scrubber; the shortcuts
      // table is not, and its error quotes the TV.
      final device = savedTv(name: 'Bedroom TV', nickname: 'Big screen');
      const disk = _DiskError(
        'database disk image is malformed (reading shortcuts of Bedroom TV, '
        'Big screen, at 192.168.0.20)',
      );
      final tvData = ['Bedroom TV', 'Big screen', '192.168.0.20'];
      final logging = RecordingCrashReporter();
      final reporter = DelegatingCrashReporter(logging);
      final crashSink = RecordingCrashlyticsSink();
      final analytics = RecordingAnalyticsSink();
      final devices = InMemoryDeviceRepository([device]);

      // The test app's platform fakes, minus what bootstrap provides itself.
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
      final platformFakes = [
        for (final o in testAppOverrides(
          store: await SettingsStore.open(),
          db: unused,
          initialLocation: AppRoutes.remote,
        ))
          if (!providedByBootstrap.contains(o.origin)) o,
      ];

      final app = await buildRootWidget(
        flavor: Flavor.dev,
        crashReporter: reporter,
        serviceConfig: const ServiceConfig(firebaseEnabled: true),
        initFirebase: (_) async => FirebaseStatus.ready,
        // An early failure, before the saved names are known: logged only.
        startupSteps: [() async => throw StateError('lost Bedroom TV')],
        openSettings: () async {
          final store = await SettingsStore.open();
          // A region where sharing is on, so reports and events are sent.
          await store.setConsentRegion(ConsentRegion.notRequired);
          await store.setOnboardingComplete(true);
          await store.setShortcutsSeeded(true);
          await store.setLocaleCode(code);
          return store;
        },
        openDatabase: () => AppDatabase(NativeDatabase.memory()),
        overrides: mergeOverrides(platformFakes, [
          ...fakeAdsOverrides(),
          remoteConfigSourceProvider.overrideWithValue(FakeConfigSource({})),
          crashlyticsSinkProvider.overrideWithValue(crashSink),
          crashDebugBuildProvider.overrideWithValue(false),
          analyticsSinkProvider.overrideWithValue(analytics),
          analyticsDebugBuildProvider.overrideWithValue(true),
          deviceRepositoryProvider.overrideWithValue(devices),
          savedDevicesProvider.overrideWith(
            (ref) => ref.watch(deviceRepositoryProvider).watchAll(),
          ),
          shortcutRepositoryProvider.overrideWithValue(
            _UnreadableShortcuts(disk),
          ),
        ]),
      );
      await t.pumpWidget(app);
      await t.pumpAndSettle();
      // The last-used TV opens the remote, in the chosen language.
      expect(find.byType(RemoteScreen), findsOneWidget);
      expect(find.text(l.statusConnected), findsOneWidget);
      expect(reporter.delegate, isA<CompositeCrashReporter>());

      unawaited(_containerOf(t).read(appRouterProvider).push(AppRoutes.apps));
      // At once: a frame for the push and one for the failed stream, not
      // after ~38 s of retries.
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text(l.appsLoadFailed), findsOneWidget);
      await t.pumpAndSettle();
      expect(find.text(l.appsLoadFailed), findsOneWidget);

      // The storage error reaches the reporter as the error handlers send it
      // (a framework error) and as a caught error.
      await reporter.recordFlutterError(
        const FlutterErrorDetails(exception: disk),
        fatal: true,
      );
      await reporter.recordError(disk, StackTrace.current);

      expect(crashSink.errors, hasLength(2));
      final sent = [
        for (final e in crashSink.errors) ...[
          e.error.toString(),
          '${e.reason}',
          '${e.stack}',
        ],
      ];
      for (final data in tvData) {
        expect(
          sent.where((s) => s.contains(data)),
          isEmpty,
          reason: 'a crash report carried "$data"',
        );
      }
      expect(sent.first, contains('<tv>'));
      expect(sent.first, contains('<ip>'));
      // The early failure was logged here, never sent.
      expect(
        logging.errors.map((e) => e.reason),
        contains('startup step 1'),
      );
      _expectNoTvDataIn(analytics, tvData, why: 'storage error $code');
      expect(t.takeException(), isNull);
    });

    testWidgets(
      'the_fake_tv_pairs_presses_and_resumes_without_a_leak_$code',
      (t) async {
        _phone(t);
        final l = _strings(locale);
        final harness = await FakeTvHarness.start(t);
        addTearDown(harness.close);
        final fakeTv = harness.tv;
        final signals = ManualSessionSignals();
        final analytics = RecordingAnalyticsSink();
        await withSemantics(t, () async {
          await harness.cleanUpAfter(() async {
            await pumpRouterApp(
              t,
              initialLocation: AppRoutes.discover,
              locale: locale,
              settle: false,
              overrides: [
                ...harness.overrides,
                sessionSignalsProvider.overrideWithValue(signals),
                // The socket closes as soon as the app is in the background.
                sessionTimingProvider.overrideWithValue(
                  const SessionTiming(
                    backgroundGrace: Duration.zero,
                    nudgeDebounce: Duration.zero,
                  ),
                ),
                analyticsSinkProvider.overrideWithValue(analytics),
                analyticsDebugBuildProvider.overrideWithValue(true),
              ],
            );
            await pumpUntil(
              t,
              () => find.text('Fake TV').evaluate().isNotEmpty,
              reason: 'the fake TV in the list of TVs',
            );
            await t.tap(find.text('Fake TV'));
            final codeField = find.descendant(
              of: find.byType(PairingCodeField),
              matching: find.byType(TextField),
            );
            await pumpUntil(
              t,
              () =>
                  codeField.evaluate().isNotEmpty &&
                  fakeTv.displayedCode != null,
              reason: 'the code field and a code on the TV',
            );
            final pin = fakeTv.displayedCode!;
            await t.enterText(codeField, pin);
            final container = _containerOf(t);
            // The state the remote shows. Its status pill cross-fades, and
            // fake time stands still while real sockets work, so the old
            // label can linger in the tree: the state is what counts.
            bool connected() =>
                find.byType(RemoteScreen).evaluate().isNotEmpty &&
                container.read(connectionStateProvider).value?.status ==
                    ConnectionStatus.connected;
            await pumpUntil(
              t,
              connected,
              reason: 'the remote, connected, in $code',
            );
            await t.pumpAndSettle();
            expect(find.text(l.statusConnected), findsOneWidget);

            await t.tap(find.bySemanticsLabel(l.keyHome));
            await pumpUntil(
              t,
              () => fakeTv.receivedKeyCodes.contains(KeyCodes.home),
              reason: 'the TV to receive ${l.keyHome}',
            );
            await t.tap(find.bySemanticsLabel(l.keyVolumeUp));
            await pumpUntil(
              t,
              () => fakeTv.receivedKeyCodes.contains(KeyCodes.volumeUp),
              reason: 'the TV to receive ${l.keyVolumeUp}',
            );
            expect(fakeTv.openRemoteConnections, 1);
            final accepted = fakeTv.acceptedRemoteConnections;
            final listeners = signals.visibilityListeners;

            // Background (the socket closes) and back (one new socket).
            const cycles = 3;
            for (var i = 0; i < cycles; i++) {
              signals.background();
              await t.pump();
              await pumpUntil(
                t,
                () => fakeTv.openRemoteConnections == 0 && !connected(),
                reason: 'cycle $i: the socket closes in the background',
              );
              signals.foreground();
              await t.pump();
              await pumpUntil(
                t,
                () =>
                    fakeTv.openRemoteConnections == 1 &&
                    fakeTv.acceptedRemoteConnections == accepted + i + 1 &&
                    connected(),
                reason: 'cycle $i: connected again on one socket',
              );
            }
            expect(fakeTv.openRemoteConnections, 1);
            expect(fakeTv.acceptedRemoteConnections, accepted + cycles);
            expect(signals.visibilityListeners, listeners);
            // Let the status pill finish its cross-fade.
            await t.pump(const Duration(milliseconds: 500));
            expect(find.text(l.statusConnected), findsOneWidget);

            int volumeUps() => fakeTv.receivedKeyCodes
                .where((k) => k == KeyCodes.volumeUp)
                .length;
            final before = volumeUps();
            await t.tap(find.bySemanticsLabel(l.keyVolumeUp));
            await pumpUntil(
              t,
              () => volumeUps() > before,
              reason: 'a key still reaches the TV after the resumes',
            );
            _expectNoTvDataIn(analytics, [
              'Fake TV',
              '127.0.0.1',
              '${fakeTv.remotePort}',
              pin,
            ], why: 'fake TV flow $code');
          });
        });
      },
      tags: ['integration'],
      timeout: const Timeout(Duration(minutes: 2)),
    );

    testWidgets('reduce_motion_leaves_nothing_moving_$code', (t) async {
      _phone(t);
      final l = _strings(locale);
      await _pump(
        t,
        locale,
        AppRoutes.onboarding,
        withSavedTv: false,
        disableAnimations: true,
      );
      void still(String step) {
        expect(t.hasRunningAnimations, isFalse, reason: '$code $step');
        expect(t.takeException(), isNull, reason: '$code $step');
      }

      await t.tap(find.text(l.onboardingNext));
      await t.pump();
      expect(find.text(l.onboardingControlTitle), findsOneWidget);
      still('onboarding next');

      await t.tap(find.text(l.onboardingTryDemo));
      await t.pump();
      expect(find.byType(RemoteScreen), findsOneWidget);
      expect(
        ModalRoute.of(t.element(find.byType(RemoteScreen)))!.animation!.value,
        1,
        reason: '$code: the remote opens in one frame',
      );
      await t.pump(const Duration(milliseconds: 700));
      await t.pump();
      expect(find.text(l.statusConnected), findsOneWidget);
      still('demo connected');

      await t.tap(find.text(l.demoLeaveAction));
      await t.pump();
      expect(find.byType(AppDialog<bool>), findsOneWidget);
      still('leave dialog');
      await t.tap(find.text(l.demoStay));
      await t.pump();
      expect(find.byType(AppDialog<bool>), findsNothing);
      still('dialog closed');

      await t.tap(find.byTooltip(l.pageTitleSettings));
      await t.pump();
      expect(find.text(l.pageTitleSettings), findsWidgets);
      still('settings push');
    });
  }

  testWidgets('every_route_meets_the_guidelines_in_both_languages', (t) async {
    expect(_routes.keys.toSet(), AppRouteNames.all, reason: 'every route');
    _phone(t);
    await withSemantics(t, () async {
      for (final locale in _languages) {
        final opened = <String>{};
        for (final MapEntry(key: name, value: open) in _routes.entries) {
          final why = '$name ${locale.languageCode}';
          await open(t, locale);
          expect(
            Localizations.localeOf(
              t.element(find.byType(Scaffold).first),
            ),
            locale,
            reason: why,
          );
          final state = _containerOf(t).read(appRouterProvider).state;
          opened.add(state.name!);
          expect(state.name, name, reason: why);
          expectNoClipping(t, reason: why);
          await expectMeetsGuidelines(t, reason: why);
          // Leave before the next route: spinners never settle.
          await t.pumpWidget(const SizedBox.shrink());
        }
        expect(opened, AppRouteNames.all, reason: locale.languageCode);
      }
    });
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'field_errors_are_never_cut_at_320dp_and_200_percent_${brightness.name}',
      (t) async {
        _phone(t, const Size(320, 640));
        final scalers = <(String, double, TextScaler?)>[
          ('200%', 2, null),
          ('non-linear', 1, const NonlinearTwoXScaler()),
        ];
        for (final locale in _languages) {
          for (final (scale, textScale, scaler) in scalers) {
            final why = '${locale.languageCode} $scale ${brightness.name}';
            Future<void> pump(
              String route, {
              List<Override> overrides = const [],
            }) => _pump(
              t,
              locale,
              route,
              textScale: textScale,
              textScaler: scaler,
              brightness: brightness,
              overrides: overrides,
            );

            // A new shortcut saved with no name or ID.
            await pump(
              AppRoutes.manageApps,
              overrides: [
                shortcutRepositoryProvider.overrideWithValue(
                  InMemoryShortcutRepository(),
                ),
              ],
            );
            var l = _l(t);
            await t.tap(find.byTooltip(l.manageAppsAdd));
            await t.pumpAndSettle();
            await t.scrollUntilVisible(
              find.text(l.addAppCustom),
              200,
              scrollable: find.byType(Scrollable).last,
            );
            await t.tap(find.text(l.addAppCustom));
            await t.pumpAndSettle();
            await _expectWhole(
              t,
              l.shortcutPackageHelp,
              '$why shortcut package helper',
            );
            await t.ensureVisible(find.text(l.commonSave));
            await t.pumpAndSettle();
            await t.tap(find.text(l.commonSave));
            await t.pumpAndSettle();
            await _expectWhole(t, l.shortcutNameError, '$why shortcut name');
            await _expectWhole(
              t,
              l.shortcutPackageError,
              '$why shortcut package',
            );
            await t.pumpWidget(const SizedBox.shrink());

            // Edit TV: the name's helper, then its error.
            await pump(AppRoutes.editDevice(_tvName));
            l = _l(t);
            await _expectWhole(
              t,
              l.editDeviceNameHelp(_tvName),
              '$why edit TV helper',
            );
            final nameField = find.widgetWithText(
              TextField,
              l.editDeviceNameLabel,
            );
            await t.enterText(nameField, 'N' * 41);
            await t.pump();
            await t.ensureVisible(find.text(l.commonSave));
            await t.pumpAndSettle();
            await t.tap(find.text(l.commonSave));
            await t.pumpAndSettle();
            await _expectWhole(t, l.editDeviceNameError, '$why edit TV error');
            await t.pumpWidget(const SizedBox.shrink());

            // Pairing: a code that doesn't match.
            await _openPairing(
              t,
              locale,
              textScale: textScale,
              textScaler: scaler,
              brightness: brightness,
            );
            l = _l(t);
            await t.enterText(find.byType(TextField), '000000');
            await t.pump();
            await t.pump();
            await _expectWhole(t, l.pairCodeMismatch, '$why pairing code');
            await t.pumpWidget(const SizedBox.shrink());
          }
        }
      },
    );
  }

  test('backup_rules_and_privacy_copy_agree', () {
    // Backup and device transfer are off (Ruling P8-R1).
    final tag = _applicationTag();
    expect(tag, contains('android:allowBackup="false"'));
    expect(tag, contains('android:fullBackupContent="false"'));
    expect(
      tag,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
    final rules = File(
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    ).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');
    expect(rules, isNot(contains('<include')));
    for (final section in const ['cloud-backup', 'device-transfer']) {
      final body = RegExp('<$section>(.*?)</$section>').firstMatch(rules);
      expect(body, isNotNull, reason: section);
      final excluded = RegExp(
        r'<exclude domain="([^"]+)" path="\."\s*/>',
      ).allMatches(body!.group(1)!).map((m) => m.group(1)).toSet();
      expect(excluded, {
        'root',
        'file',
        'database',
        'sharedpref',
        'external',
        'device_root',
        'device_file',
        'device_database',
        'device_sharedpref',
      }, reason: section);
    }
    // The copy in both languages promises exactly that.
    final en = _arb('en');
    final ms = _arb('ms');
    expect(en['privacyIntro'], contains('never leave this phone'));
    expect(
      ms['privacyIntro'],
      contains('tidak pernah keluar dari telefon ini'),
    );
    expect(en['faqNewPhoneA'], contains("aren't copied by backups"));
    expect(ms['faqNewPhoneA'], contains('tidak disalin dalam sandaran'));
  });

  test('no_app_lib_file_imports_the_fake_tv', () {
    const forbidden = [
      'package:atv_remote/testing.dart',
      'package:atv_remote/src/testing/',
    ];
    final files = [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart')) file,
    ];
    expect(files, isNotEmpty);
    final offenders = [
      for (final file in files)
        for (final uri in forbidden)
          if (file.readAsStringSync().contains(uri))
            '${file.path.replaceAll(r'\', '/')}: $uri',
    ];
    expect(offenders, isEmpty);
    // The scan would see one: the test harness does import it.
    expect(
      File('test/helpers/fake_tv_harness.dart').readAsStringSync(),
      contains(forbidden.first),
    );
  });
}
