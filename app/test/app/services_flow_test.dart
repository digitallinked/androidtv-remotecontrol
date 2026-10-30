import 'dart:async';
import 'dart:io' show InternetAddress, SocketException;

import 'package:atv_remote/atv_remote.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/theme/colour_styles.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/core/ads/ads_service.dart';
import 'package:tv_remote/core/ads/consent_service.dart';
import 'package:tv_remote/core/ads/tracking_service.dart';
import 'package:tv_remote/core/analytics/analytics_hooks.dart';
import 'package:tv_remote/core/analytics/app_analytics.dart';
import 'package:tv_remote/core/config/app_config.dart';
import 'package:tv_remote/core/crash/crash_collection.dart';
import 'package:tv_remote/core/crash/crash_reporter.dart';
import 'package:tv_remote/core/firebase/firebase_bootstrap.dart';
import 'package:tv_remote/core/links/link_opener.dart';
import 'package:tv_remote/core/privacy/privacy_choices.dart';
import 'package:tv_remote/core/purchases/purchase_service.dart';
import 'package:tv_remote/core/review/review_prompter.dart';
import 'package:tv_remote/core/session/remote_client_factory.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/apps/data/apps_data_providers.dart';
import 'package:tv_remote/features/apps/presentation/apps_screen.dart';
import 'package:tv_remote/features/discovery/data/discovery_providers.dart';
import 'package:tv_remote/features/pairing/data/pairing_providers.dart';
import 'package:tv_remote/features/paywall/presentation/paywall_screen.dart';
import 'package:tv_remote/features/remote/presentation/remote_screen.dart';
import 'package:tv_remote/features/settings/presentation/appearance_page.dart';

import '../helpers/ad_clearance.dart';
import '../helpers/fake_ads_sdk.dart';
import '../helpers/fake_consent_service.dart';
import '../helpers/fake_pairing_client.dart';
import '../helpers/fake_purchase_service.dart';
import '../helpers/fake_remote_client.dart';
import '../helpers/fake_tracking_service.dart';
import '../helpers/fake_tv_discovery.dart';
import '../helpers/in_memory_device_repository.dart';
import '../helpers/in_memory_shortcut_repository.dart';
import '../helpers/nonlinear_text_scaler.dart';
import '../helpers/platform_override.dart';
import '../helpers/pump_router_app.dart';
import '../helpers/recording_analytics_sink.dart';
import '../helpers/recording_crashlytics_sink.dart';
import '../helpers/recording_link_opener.dart';
import '../helpers/test_app_config.dart';
import '../helpers/test_devices.dart';

/// Seam tests for Phase 6: the services (consent, tracking, ads, Premium,
/// Remote Config, analytics, crash reports and the review prompt) working
/// together with the real `App`, router, screens, providers and
/// `TvRemoteSession`. Only the TV (clients, pairing, discovery), the stores
/// (in memory) and the vendor SDKs behind our interfaces are faked.
void main() {
  late InMemoryDeviceRepository devices;
  late InMemoryShortcutRepository shortcuts;
  late FakeRemoteClients clients;
  late FakePairingClients pairings;
  late FakeTvDiscoveries discoveries;
  late RecordingAnalyticsSink sink;
  late RecordingCrashlyticsSink crashSink;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  setUp(() {
    _reached.clear();
    devices = InMemoryDeviceRepository();
    shortcuts = InMemoryShortcutRepository();
    clients = FakeRemoteClients();
    pairings = FakePairingClients();
    discoveries = FakeTvDiscoveries();
    sink = RecordingAnalyticsSink();
    crashSink = RecordingCrashlyticsSink();
  });

  final banner = find.byKey(const ValueKey('fake_banner'));

  ProviderContainer containerOf(WidgetTester t) =>
      ProviderScope.containerOf(t.element(find.byType(MaterialApp)));

  /// Firebase running, with recording sinks behind analytics and Crashlytics,
  /// as a release build would send crash reports: the crash reporter is the
  /// scrubbing one, as bootstrap installs it once Firebase is ready.
  List<Override> firebaseReady() => [
    firebaseStatusProvider.overrideWithValue(FirebaseStatus.ready),
    crashlyticsSinkProvider.overrideWithValue(crashSink),
    crashDebugBuildProvider.overrideWithValue(false),
    crashReporterProvider.overrideWith(
      (ref) => ref.watch(crashCollectionProvider.notifier).reporter,
    ),
    // No Remote Config platform in tests.
    remoteConfigSourceProvider.overrideWithValue(
      const DefaultsOnlyConfigSource(),
    ),
  ];

  /// Opens the real app at [location] on a phone-sized view, on the stores
  /// and TV fakes above. The analytics guard throws, as in a debug build.
  Future<ProviderContainer> pump(
    WidgetTester t, {
    String location = AppRoutes.onboarding,
    List<Override> overrides = const [],
    Future<void> Function(SettingsStore store)? prepareSettings,
    bool settle = true,
  }) async {
    t.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpRealApp(
      t,
      initialLocation: location,
      settle: settle,
      prepareSettings: prepareSettings,
      overrides: [
        deviceRepositoryProvider.overrideWithValue(devices),
        savedDevicesProvider.overrideWith(
          (ref) => ref.watch(deviceRepositoryProvider).watchAll(),
        ),
        remoteClientFactoryProvider.overrideWithValue(clients.create),
        pairingClientFactoryProvider.overrideWithValue(pairings.create),
        tvDiscoveryFactoryProvider.overrideWithValue(discoveries.create),
        shortcutRepositoryProvider.overrideWithValue(shortcuts),
        analyticsSinkProvider.overrideWithValue(sink),
        analyticsDebugBuildProvider.overrideWithValue(true),
        ...overrides,
      ],
    );
    if (!settle) await t.pump();
    // As bootstrap does once Firebase is ready: the crash collection keeps
    // following the privacy choice.
    return containerOf(t)..listen(crashCollectionProvider, (_, _) {});
  }

  Future<void> tapAndSettle(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Future<void> back(WidgetTester t, [int times = 1]) async {
    for (var i = 0; i < times; i++) {
      await t.pageBack();
      await t.pumpAndSettle();
    }
  }

  Future<void> openSettings(WidgetTester t) async {
    await t.tap(find.byTooltip('Settings'));
    await t.pumpAndSettle();
  }

  /// Onboarding → the last card → Get started (on iOS, then the Local
  /// Network explainer's Continue) → the discovery screen.
  Future<void> getStarted(WidgetTester t) async {
    for (var i = 0; i < 2; i++) {
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
    }
    await t.tap(find.text('Get started'));
    await t.pump();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await t.pumpAndSettle();
      await t.tap(find.text('Continue'));
      await t.pump();
    }
    await t.pump(const Duration(milliseconds: 400));
    expect(discoveries.created, isNotEmpty);
  }

  /// On the discovery screen: the TV [name] at [host] shows up, is tapped and
  /// paired with [code]; the remote opens connected.
  Future<void> discoverAndPair(
    WidgetTester t, {
    String name = 'Living Room TV 3',
    String host = '192.168.0.20',
    String code = 'AB12CD',
  }) async {
    pairings.onCreate = (client) => client.validCode = code;
    discoveries.created.last.emit([tv(name, host: host)]);
    await t.pump();
    await t.tap(find.text(name));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.enterText(find.byType(TextField), code);
    await t.pumpAndSettle();
    expect(find.byType(RemoteScreen), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
  }

  Future<void> tapVolumeUp(WidgetTester t) async {
    await t.tap(find.bySemanticsLabel('Volume up'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
  }

  bool switchValue(WidgetTester t, String title) => t
      .widget<Switch>(
        find.descendant(
          of: find.ancestor(
            of: find.text(title),
            matching: find.byType(ListTile),
          ),
          matching: find.byType(Switch),
        ),
      )
      .value;

  /// Nothing on screen talks about a failure: no snack bar, no dialog, no
  /// error text.
  void expectNoFailureShown(WidgetTester t, String where) {
    expect(t.takeException(), isNull, reason: where);
    expect(find.byType(SnackBar), findsNothing, reason: where);
    expect(find.byType(Dialog), findsNothing, reason: where);
    for (final text in ['wrong', 'error', 'Error', 'failed', "Couldn't"]) {
      expect(find.textContaining(text), findsNothing, reason: '$where $text');
    }
  }

  _semanticsTest('the_remote_works_with_every_service_failing', (t) async {
    final container = await pump(
      t,
      // A launch on which the review prompt would be asked, so the failing
      // review API is reached too.
      prepareSettings: (store) async {
        await store.setLaunchCount(5);
        await store.setReviewKeyPresses(1000);
      },
      overrides: [
        firebaseStatusProvider.overrideWithValue(FirebaseStatus.unavailable),
        consentServiceProvider.overrideWithValue(_ThrowingConsent()),
        trackingServiceProvider.overrideWithValue(_ThrowingTracking()),
        adsSdkProvider.overrideWithValue(_ThrowingAds()),
        purchaseServiceProvider.overrideWithValue(_ThrowingPurchases()),
        remoteConfigSourceProvider.overrideWithValue(_ThrowingConfig()),
        reviewRequesterProvider.overrideWithValue(_ThrowingReview()),
      ],
    );
    // The config step of startup, as bootstrap runs it.
    await container.read(appConfigProvider.notifier).load();
    container.read(appConfigProvider.notifier).seal();
    await t.pumpAndSettle();
    expect(container.read(appConfigProvider), AppConfigValues.defaults);
    expectNoFailureShown(t, 'onboarding');

    await getStarted(t);
    await discoverAndPair(t);
    expectNoFailureShown(t, 'remote');

    await tapVolumeUp(t);
    expect(
      clients.created.single.sentKeys,
      contains((KeyCodes.volumeUp, KeyDirection.short)),
    );

    // Settings (and leaving it, where an interstitial may show) and Apps:
    // no banner, no failure.
    await openSettings(t);
    expect(find.text('Settings'), findsWidgets);
    expect(banner, findsNothing);
    expect(find.text('Advertisement'), findsNothing);
    expectNoFailureShown(t, 'settings');
    await back(t);
    expect(find.byType(RemoteScreen), findsOneWidget);
    await t.tap(find.text('All apps'));
    await t.pumpAndSettle();
    expect(find.byType(AppsScreen), findsOneWidget);
    expect(banner, findsNothing);
    expect(find.text('Advertisement'), findsNothing);
    expectNoFailureShown(t, 'apps');
    await back(t);

    // The paywall says so, in its own words.
    await openSettings(t);
    await tapAndSettle(t, find.text('Premium'));
    expect(find.byType(PaywallScreen), findsOneWidget);
    expect(find.text("Premium isn't available right now"), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.tap(find.byTooltip('Close'));
    await t.pumpAndSettle();
    await back(t);

    // Still working after all of it, and nothing reached the review API's
    // failure on screen.
    await tapVolumeUp(t);
    expect(
      clients.created.single.sentKeys
          .where((k) => k == (KeyCodes.volumeUp, KeyDirection.short))
          .length,
      2,
    );
    expect(find.text('Connected'), findsOneWidget);
    expectNoFailureShown(t, 'remote again');
    // The failures were met, not avoided. (On Android nothing asks the
    // tracking question, and with consent failing the ads SDK never starts.)
    expect(_reached, containsAll(['consent', 'store', 'config', 'review']));
  });

  /// Every service fails except consent, which allows ads: the banner then
  /// goes on to [tracking] and the ads SDK, which fails. The remote,
  /// Settings and Apps work as before and nothing is shown.
  Future<void> adsFailAfterConsent(
    WidgetTester t, {
    required TrackingService tracking,
  }) async {
    await pump(
      t,
      overrides: [
        firebaseStatusProvider.overrideWithValue(FirebaseStatus.unavailable),
        consentServiceProvider.overrideWithValue(FakeConsentService()),
        trackingServiceProvider.overrideWithValue(tracking),
        adsSdkProvider.overrideWithValue(_ThrowingAds()),
        purchaseServiceProvider.overrideWithValue(_ThrowingPurchases()),
        remoteConfigSourceProvider.overrideWithValue(_ThrowingConfig()),
        reviewRequesterProvider.overrideWithValue(_ThrowingReview()),
      ],
    );
    await getStarted(t);
    await discoverAndPair(t);
    await tapVolumeUp(t);
    // The store never answered: the cached "free" becomes final, so the
    // banner may try.
    await t.pump(const Duration(seconds: 6));
    await t.pumpAndSettle();

    await openSettings(t);
    expect(banner, findsNothing);
    expect(find.text('Advertisement'), findsNothing);
    expectNoFailureShown(t, 'settings');
    await back(t);
    expect(find.byType(RemoteScreen), findsOneWidget);
    await t.tap(find.text('All apps'));
    await t.pumpAndSettle();
    expect(find.byType(AppsScreen), findsOneWidget);
    expect(banner, findsNothing);
    expect(find.text('Advertisement'), findsNothing);
    expectNoFailureShown(t, 'apps');
    await back(t);

    await tapVolumeUp(t);
    expect(
      clients.created.single.sentKeys
          .where((k) => k == (KeyCodes.volumeUp, KeyDirection.short))
          .length,
      2,
    );
    expect(find.text('Connected'), findsOneWidget);
    expectNoFailureShown(t, 'remote again');
  }

  testWidgets(
    'the_remote_works_when_ads_and_tracking_fail_after_consent_android',
    (t) async {
      // Android has no tracking question: its answer is "not applicable".
      await _withSemantics(
        t,
        () => adsFailAfterConsent(t, tracking: FakeTrackingService()),
      );
      // The SDK's start was tried, and failed.
      expect(_reached, contains('ads'));
      expect(_reached, isNot(contains('tracking')));
    },
  );

  testWidgetsOn(
    TargetPlatform.iOS,
    'the_remote_works_when_ads_and_tracking_fail_after_consent_ios',
    (t) async {
      await _withSemantics(
        t,
        () => adsFailAfterConsent(t, tracking: _ThrowingTracking()),
      );
      // The tracking question failed, so there was no pre-prompt left
      // behind. And with no tracking answer, no ad request goes out: the
      // SDK is never started (Ruling P6-R8).
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('About ads in this app'), findsNothing);
      expect(_reached, contains('tracking'));
      expect(_reached, isNot(contains('ads')));
    },
  );

  testWidgets(
    'first_launch_in_the_eea_asks_on_the_remote_and_shares_nothing_by_default',
    (t) async {
      // The silent update is slow, so the events of onboarding and pairing
      // wait in the buffer for the region.
      final update = Completer<void>();
      final consent = FakeConsentService(
        region: ConsentRegion.required,
        formOutcome: ConsentFormOutcome.shown,
        holdRequestUpdate: update,
      );
      final container = await pump(
        t,
        overrides: [
          ...firebaseReady(),
          consentServiceProvider.overrideWithValue(consent),
          adsSdkProvider.overrideWithValue(FakeAdsSdk(loads: true)),
          analyticsSamplerProvider.overrideWithValue(() => 0),
        ],
      );

      await getStarted(t);
      expect(consent.showFormCalls, 0, reason: 'never over discovery');
      await discoverAndPair(t);
      expect(container.read(privacyChoicesProvider).usageDecided, isFalse);
      expect(sink.calls, isEmpty, reason: 'waiting for the region');
      expect(consent.showFormCalls, 0);

      update.complete();
      await t.pumpAndSettle();
      // The form, once, on the remote; the waiting events were dropped.
      expect(find.byType(RemoteScreen), findsOneWidget);
      expect(consent.showFormCalls, 1);
      expect(sink.calls, isEmpty);
      expect(sink.collectionHistory, everyElement(isFalse));
      expect(crashSink.collectionHistory, everyElement(isFalse));
      expect(crashSink.deletes, greaterThanOrEqualTo(1));

      // Nothing about the crash either.
      await container
          .read(crashReporterProvider)
          .recordError(StateError('boom'), StackTrace.current);
      expect(crashSink.errors, isEmpty);

      // Ads were consented to: the hub shows the banner.
      await openSettings(t);
      expect(banner, findsOneWidget);
      await tapAndSettle(t, find.text('Privacy choices'));
      expect(switchValue(t, 'Share usage statistics'), isFalse);
      expect(switchValue(t, 'Share crash reports'), isFalse);
      await back(t, 2);
      expect(find.byType(RemoteScreen), findsOneWidget);
      expect(consent.showFormCalls, 1, reason: 'once per launch');

      // Turning usage on sends what happens from then on only: the events
      // that waited were dropped, not kept.
      await openSettings(t);
      await tapAndSettle(t, find.text('Privacy choices'));
      await tapAndSettle(t, find.text('Share usage statistics'));
      expect(switchValue(t, 'Share usage statistics'), isTrue);
      await back(t, 2);
      expect(sink.collectionHistory.last, isTrue);
      for (final name in [
        'onboarding_complete',
        'tv_discovered',
        'pair_start',
        'pair_success',
        'connect_success',
      ]) {
        expect(sink.eventNames, isNot(contains(name)), reason: name);
      }
      expect(sink.screens, isNot(contains('onboarding')));
      expect(sink.screens, isNot(contains('pair')));
      // And now it does share.
      expect(sink.screens, contains('remote'));
    },
  );

  _semanticsTest('outside_the_eea_sharing_is_on_until_turned_off', (t) async {
    final update = Completer<void>();
    final consent = FakeConsentService(holdRequestUpdate: update);
    final container = await pump(
      t,
      overrides: [
        ...firebaseReady(),
        consentServiceProvider.overrideWithValue(consent),
        analyticsSamplerProvider.overrideWithValue(() => 0),
      ],
    );

    await getStarted(t);
    await discoverAndPair(t);
    expect(sink.calls, isEmpty, reason: 'waiting for the region');

    update.complete();
    await t.pumpAndSettle();
    // The region needs no consent: what waited is sent, in order.
    expect(sink.eventNames, [
      'onboarding_complete',
      'tv_discovered',
      'pair_start',
      'pair_success',
      'connect_success',
    ]);
    expect(
      sink.screens,
      containsAllInOrder(['onboarding', 'discover', 'pair', 'remote']),
    );
    expect(sink.collectionHistory, [false, true]);
    expect(crashSink.collectionHistory.last, isTrue);
    expect(consent.showFormCalls, 1);

    await tapVolumeUp(t);
    expect(sink.eventNames.last, 'key_press');
    await container
        .read(crashReporterProvider)
        .recordError(StateError('first'), StackTrace.current);
    expect(crashSink.errors, hasLength(1));

    // Turn both off.
    await openSettings(t);
    await tapAndSettle(t, find.text('Privacy choices'));
    expect(switchValue(t, 'Share usage statistics'), isTrue);
    expect(switchValue(t, 'Share crash reports'), isTrue);
    await tapAndSettle(t, find.text('Share usage statistics'));
    await tapAndSettle(t, find.text('Share crash reports'));
    expect(switchValue(t, 'Share usage statistics'), isFalse);
    expect(switchValue(t, 'Share crash reports'), isFalse);
    // Collection is off natively, and what the device kept is deleted.
    expect(sink.collectionHistory.last, isFalse);
    expect(crashSink.collectionHistory.last, isFalse);
    expect(crashSink.calls.last, 'enable:false');
    expect(crashSink.calls, contains('delete'));

    final events = sink.events.length;
    final screens = sink.screens.length;
    await back(t, 2);
    await tapVolumeUp(t);
    await t.tap(find.text('All apps'));
    await t.pumpAndSettle();
    await t.tap(find.text('Netflix'));
    await t.pumpAndSettle();
    await container
        .read(crashReporterProvider)
        .recordError(StateError('second'), StackTrace.current);

    expect(sink.events, hasLength(events));
    expect(sink.screens, hasLength(screens));
    expect(crashSink.errors, hasLength(1));
  });

  testWidgets('buying_premium_removes_banners_and_unlocks_styles', (t) async {
    final purchases = FakePurchaseService(
      offer: testOffer(),
      nextPurchase: const Purchased(EntitlementSnapshot(active: true)),
    );
    final sdk = FakeAdsSdk(loads: true);
    devices = InMemoryDeviceRepository([savedTv()]);
    final container = await pump(
      t,
      location: AppRoutes.remote,
      overrides: [
        purchaseServiceProvider.overrideWithValue(purchases),
        adsSdkProvider.overrideWithValue(sdk),
      ],
    );
    // The store says: free.
    purchases.emit(const EntitlementSnapshot(active: false));
    await t.pumpAndSettle();

    await openSettings(t);
    expect(banner, findsOneWidget, reason: 'a free user sees the banner');

    await tapAndSettle(t, find.text('Appearance'));
    await tapAndSettle(t, find.text('Ember'));
    // Locked: the paywall, from the styles, and nothing changed.
    expect(find.byType(PaywallScreen), findsOneWidget);
    expect(
      GoRouterState.of(
        t.element(find.byType(PaywallScreen)),
      ).uri.queryParameters['source'],
      'themes',
    );
    expect(
      container.read(settingsStoreProvider).colourStyle,
      isNot(ColourStyle.ember),
    );

    await tapAndSettle(t, find.widgetWithText(FilledButton, 'Continue'));
    expect(purchases.purchases, [PremiumPlanKind.yearly]);
    expect(find.text('Welcome to Premium. Thank you!'), findsOneWidget);
    expect(find.byType(PaywallScreen), findsNothing);
    expect(find.byType(AppearancePage), findsOneWidget);

    await tapAndSettle(t, find.text('Ember'));
    expect(
      container.read(settingsStoreProvider).colourStyle,
      ColourStyle.ember,
    );
    expect(
      Theme.of(t.element(find.byType(AppearancePage))).extension<AppColors>(),
      colourStyleColors(ColourStyle.ember, Brightness.light),
    );
    expect(find.text('Included with Premium'), findsNothing);

    // The hub's banner is gone, and Apps has none.
    final loads = sdk.bannerLoads;
    await back(t);
    expect(find.text('You have Premium. Thank you!'), findsOneWidget);
    expect(banner, findsNothing);
    expect(sdk.disposed, sdk.bannerLoads);
    await back(t);
    await t.tap(find.text('All apps'));
    await t.pumpAndSettle();
    expect(find.byType(AppsScreen), findsOneWidget);
    expect(banner, findsNothing);
    expect(sdk.bannerLoads, loads);
    await back(t);

    await openSettings(t);
    expect(banner, findsNothing);
    await tapAndSettle(t, find.text('Privacy choices'));
    expect(
      find.text('You have Premium, so the app shows no ads.'),
      findsOneWidget,
    );
    expect(find.text('Remove ads with Premium'), findsNothing);
    expect(sdk.bannerLoads, loads);
    final paywall = sink.events.where((e) => e.name == 'paywall_view');
    expect(paywall.single.params, {'source': 'themes', 'variant': 'a'});
    final bought = sink.events.where((e) => e.name == 'purchase_success');
    expect(bought.single.params, {'product': 'premium_yearly'});
  });

  testWidgets('premium_offline_never_flashes_an_ad', (t) async {
    final sdk = FakeAdsSdk(loads: true);
    devices = InMemoryDeviceRepository([savedTv()]);
    await pump(
      t,
      location: AppRoutes.remote,
      prepareSettings: (store) =>
          store.setCachedPremium((active: true, expiresAt: null)),
      overrides: [
        purchaseServiceProvider.overrideWithValue(_SilentPurchases()),
        adsSdkProvider.overrideWithValue(sdk),
        analyticsSamplerProvider.overrideWithValue(() => 1),
      ],
    );

    Future<void> visit() async {
      await openSettings(t);
      expect(banner, findsNothing);
      await back(t);
      await t.tap(find.text('All apps'));
      await t.pumpAndSettle();
      expect(banner, findsNothing);
      await back(t);
    }

    // Before the store's answer would have been waited for, and after the
    // cache has become final.
    await visit();
    await t.pump(const Duration(seconds: 6));
    await t.pumpAndSettle();
    await visit();

    expect(sdk.bannerSizeCalls, 0);
    expect(sdk.bannerLoads, 0);
    expect(sdk.interstitialLoads, 0);
  });

  _semanticsTest('no_analytics_event_or_crash_report_carries_tv_data', (
    t,
  ) async {
    final container = await pump(
      t,
      overrides: [
        ...firebaseReady(),
        analyticsSamplerProvider.overrideWithValue(() => 0),
      ],
    );

    await getStarted(t);
    await discoverAndPair(t, code: 'A1B2C3');
    await tapVolumeUp(t);

    // Name it and give it a MAC on its own page.
    await openSettings(t);
    await tapAndSettle(t, find.text('Your TVs'));
    await tapAndSettle(t, find.text('Living Room TV 3'));
    await t.enterText(
      find.widgetWithText(TextField, 'Name on this phone'),
      'Den',
    );
    await t.enterText(
      find.widgetWithText(TextField, 'MAC address'),
      'AA:BB:CC:DD:EE:F0',
    );
    await tapAndSettle(t, find.widgetWithText(FilledButton, 'Save'));
    expect(find.text('Saved'), findsOneWidget);
    expect(devices.saved['Living Room TV 3']!.nickname, 'Den');
    expect(devices.saved['Living Room TV 3']!.wolMac, 'AA:BB:CC:DD:EE:F0');

    // A custom shortcut.
    await back(t, 2);
    await t.scrollUntilVisible(
      find.text('Apps'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tapAndSettle(t, find.text('Apps'));
    await t.tap(find.byTooltip('Add app'));
    await t.pumpAndSettle();
    await tapAndSettle(t, find.text('Create a custom shortcut'));
    await t.enterText(find.byKey(const ValueKey('shortcut_name')), 'Private');
    await t.enterText(
      find.byKey(const ValueKey('shortcut_package')),
      'com.example.private',
    );
    await tapAndSettle(t, find.widgetWithText(FilledButton, 'Save'));
    await back(t, 2);
    expect(find.byType(RemoteScreen), findsOneWidget);

    // Type on the keyboard.
    await t.tap(find.bySemanticsLabel('Keyboard'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'hunter2');
    await t.pump(const Duration(milliseconds: 150));
    expect(clients.created.last.sentTexts, ['hunter2']);
    await t.tap(find.byTooltip('Close'));
    await t.pumpAndSettle();

    // Launch the shortcut, then switch the layout.
    await t.tap(find.text('All apps'));
    await t.pumpAndSettle();
    await tapAndSettle(t, find.text('Private'));
    expect(
      clients.created.last.sentLinks,
      contains('market://launch?id=com.example.private'),
    );
    await t.tap(find.text('D-pad'));
    await t.pumpAndSettle();

    // A connection error that names the TV, through the app's reporter.
    final reporter = container.read(crashReporterProvider);
    await reporter.recordError(
      SocketException(
        'Connection to Living Room TV 3 (Den, AA:BB:CC:DD:EE:F0, '
        'key $testPin, code A1B2C3) failed',
        address: InternetAddress('192.168.0.20'),
        port: 6466,
      ),
      StackTrace.current,
      reason: 'connect to Living Room TV 3 at 192.168.0.20',
    );
    await reporter.recordFlutterError(
      FlutterErrorDetails(
        exception: StateError('Den at 192.168.0.20 went away'),
        context: ErrorDescription('while talking to Living Room TV 3'),
      ),
    );

    // Enough happened for the sweep to mean something.
    expect(
      sink.eventNames,
      containsAll([
        'onboarding_complete',
        'tv_discovered',
        'pair_start',
        'pair_success',
        'connect_success',
        'key_press',
        'app_launch',
        'layout_change',
      ]),
    );
    expect(
      sink.events.where((e) => e.name == 'app_launch').single.params,
      {'package': 'custom'},
    );
    expect(sink.screens, containsAll(['pair', 'edit_device']));
    expect(crashSink.errors, hasLength(2));

    // The scrubber ran: the TV's name and address were replaced, not the
    // reports dropped.
    final socket = crashSink.errors.first;
    expect('${socket.error}', allOf(contains('<tv>'), contains('<ip>')));
    expect(socket.reason, allOf(contains('<tv>'), contains('<ip>')));
    expect(
      '${crashSink.errors.last.error}',
      allOf(contains('<tv>'), contains('<ip>')),
    );

    // Each forbidden string, in any letter case, as a whole token (so "Den"
    // doesn't match "hidden" in a stack frame).
    final forbidden = [
      for (final word in [
        'Living Room',
        'Den',
        '192.168.0.20',
        'AA:BB:CC',
        'A1B2C3',
        'hunter2',
        'com.example.private',
        testPin,
      ])
        RegExp(
          '(?<![A-Za-z0-9])${RegExp.escape(word)}(?![A-Za-z0-9])',
          caseSensitive: false,
        ),
    ];
    final ipv4 = RegExp(r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}');
    final mac = RegExp(r'[0-9A-Fa-f]{2}([:-])(?:[0-9A-Fa-f]{2}\1){4}');
    final payloads = <String>[
      for (final e in sink.events) ...[
        e.name,
        for (final entry in e.params.entries) ...[
          entry.key,
          '${entry.value}',
        ],
      ],
      ...sink.screens,
      for (final e in crashSink.errors) ...[
        '${e.error}',
        ?e.reason,
        if (e.stack != null) '${e.stack}',
      ],
    ];
    for (final text in payloads) {
      for (final word in forbidden) {
        expect(word.hasMatch(text), isFalse, reason: '${word.pattern}: $text');
      }
      expect(ipv4.hasMatch(text), isFalse, reason: text);
      expect(mac.hasMatch(text), isFalse, reason: text);
    }
  });

  testWidgets('forced_update_blocks_every_route', (t) async {
    devices = InMemoryDeviceRepository([savedTv()]);
    final links = RecordingLinkOpener();
    final gate = [
      appConfigProvider.overrideWith(
        () => TestAppConfig({'min_supported_version': '9.0.0'}),
      ),
      linkOpenerProvider.overrideWithValue(links),
    ];

    void expectGate(String where) {
      expect(find.text('Update required'), findsOneWidget, reason: where);
      // The gate is the only screen: no route is built behind it.
      expect(find.byType(Scaffold), findsOneWidget, reason: where);
      expect(find.byType(RemoteScreen), findsNothing, reason: where);
      expect(find.text('Demo mode'), findsNothing, reason: where);
    }

    for (final route in [
      AppRoutes.onboarding,
      AppRoutes.remote,
      AppRoutes.settings,
      AppRoutes.paywallPath,
    ]) {
      await pump(t, location: route, overrides: gate);
      expectGate(route);
    }

    // The demo too.
    final container = await pump(
      t,
      location: AppRoutes.remote,
      overrides: gate,
    );
    container.read(activeTargetProvider.notifier).startDemo();
    await t.pump();
    await t.pump(const Duration(milliseconds: 700));
    await t.pumpAndSettle();
    expect(container.read(remoteSessionProvider).value?.isDemo, isTrue);
    expectGate('demo');

    // Its one action opens the store.
    await t.tap(find.text('Update'));
    await t.pumpAndSettle();
    expect(links.opened.single.host, 'play.google.com');
  });

  testWidgets('no_ad_within_48dp_of_navigation_controls_anywhere', (t) async {
    devices = InMemoryDeviceRepository([savedTv()]);
    var checks = 0;
    for (final size in const [Size(320, 640), Size(390, 844), Size(844, 390)]) {
      for (final (label, scaler) in const <(String, TextScaler)>[
        ('2x', TextScaler.linear(2)),
        ('non-linear', NonlinearTwoXScaler()),
      ]) {
        t.view
          ..physicalSize = size
          ..devicePixelRatio = 1;
        addTearDown(t.view.reset);
        // Opened from the remote, the way a user gets there: the hub and the
        // Apps screen then have a back arrow above the ad.
        await pumpRouterApp(
          t,
          initialLocation: AppRoutes.remote,
          textScaler: scaler,
          overrides: [
            deviceRepositoryProvider.overrideWithValue(devices),
            savedDevicesProvider.overrideWith(
              (ref) => ref.watch(deviceRepositoryProvider).watchAll(),
            ),
            adsSdkProvider.overrideWithValue(FakeAdsSdk(loads: true)),
          ],
        );
        final router = GoRouter.of(t.element(find.byType(RemoteScreen)));
        for (final route in [AppRoutes.settings, AppRoutes.apps]) {
          unawaited(router.push(route));
          await t.pumpAndSettle();
          final reason = '$route at $size, text $label';
          expect(find.byType(BackButton), findsOneWidget, reason: reason);
          expect(banner, findsOneWidget, reason: reason);
          final list = _longestList(t);
          for (final fraction in const [0.0, 0.5, 1.0]) {
            for (var i = 0; i < 20; i++) {
              final target = list.maxScrollExtent * fraction;
              list.jumpTo(target);
              await t.pump();
              if (list.maxScrollExtent * fraction == target) break;
            }
            expect(tappableRects(t), isNotEmpty, reason: reason);
            expectClearance(t, t.getRect(banner));
            checks++;
          }
          router.pop();
          await t.pumpAndSettle();
        }
      }
    }
    expect(checks, 3 * 2 * 2 * 3);
  });

  testWidgets('faq_privacy_answer_matches_the_behaviour', (t) async {
    devices = InMemoryDeviceRepository([savedTv()]);
    await pump(t, location: AppRoutes.remote);
    await openSettings(t);
    await tapAndSettle(t, find.text('Help'));
    await tapAndSettle(t, find.text('What does the app keep about my TV?'));
    final answer = find.textContaining('Privacy choices');
    expect(answer, findsOneWidget);
    final text = t.widget<Text>(answer).data!;
    // What it promises is what the page offers: usage statistics and crash
    // reports, each with its own switch.
    expect(text, contains('usage statistics'));
    expect(text, contains('crash reports'));
    expect(text, contains('Settings → Privacy choices'));

    await back(t);
    await tapAndSettle(t, find.text('Privacy choices'));
    expect(find.text('Share usage statistics'), findsOneWidget);
    expect(find.text('Share crash reports'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(2));
  });
}

/// The vertical scroll view of the page: the one with the most to scroll.
ScrollPosition _longestList(WidgetTester t) {
  final positions = [
    for (final state in t.stateList<ScrollableState>(find.byType(Scrollable)))
      if (state.position.axis == Axis.vertical) state.position,
  ];
  expect(positions, isNotEmpty);
  return positions.reduce(
    (a, b) => a.maxScrollExtent >= b.maxScrollExtent ? a : b,
  );
}

/// The failing services that were asked something, by name.
final Set<String> _reached = {};

/// The error a failing service throws; it notes that [what] was reached.
StateError _down(String what) {
  _reached.add(what);
  return StateError('$what is down');
}

/// Consent that fails on every call.
class _ThrowingConsent implements ConsentService {
  @override
  Future<ConsentRegion> requestUpdate() async => throw _down('consent');

  @override
  Future<ConsentFormOutcome> showFormIfRequired() async =>
      throw _down('consent');

  @override
  Future<bool> canRequestAds() async => throw _down('consent');

  @override
  Future<bool> privacyOptionsRequired() async => throw _down('consent');

  @override
  Future<bool> showPrivacyOptions() async => throw _down('consent');
}

/// Tracking that fails on every call.
class _ThrowingTracking implements TrackingService {
  @override
  Future<TrackingStatus> status() async => throw _down('tracking');

  @override
  Future<TrackingStatus> request() async => throw _down('tracking');
}

/// An ads SDK that fails on every call.
class _ThrowingAds implements AdsSdk {
  @override
  Future<void> initialize() async => throw _down('ads');

  @override
  Future<AdBannerSize?> bannerSize(Orientation orientation, int width) async =>
      throw _down('ads');

  @override
  Future<LoadedBanner?> loadBanner(String unitId, AdBannerSize size) async =>
      throw _down('ads');

  @override
  Future<LoadedInterstitial?> loadInterstitial(String unitId) async =>
      throw _down('ads');
}

/// A store that is configured but fails on every call, its entitlement
/// stream included.
class _ThrowingPurchases implements PurchaseService {
  @override
  bool get isConfigured => true;

  @override
  Future<void> configure() async => throw _down('store');

  @override
  Stream<EntitlementSnapshot> get entitlements => Stream.error(_down('store'));

  @override
  Future<PremiumOffer?> loadOffer() async => throw _down('store');

  @override
  Future<PurchaseOutcome> purchase(PremiumPlanKind kind) async =>
      throw _down('store');

  @override
  Future<RestoreOutcome> restore() async => throw _down('store');
}

/// A store that is configured and never answers.
class _SilentPurchases implements PurchaseService {
  @override
  bool get isConfigured => true;

  @override
  Future<void> configure() => Completer<void>().future;

  @override
  Stream<EntitlementSnapshot> get entitlements => const Stream.empty();

  @override
  Future<PremiumOffer?> loadOffer() => Completer<PremiumOffer?>().future;

  @override
  Future<PurchaseOutcome> purchase(PremiumPlanKind kind) =>
      Completer<PurchaseOutcome>().future;

  @override
  Future<RestoreOutcome> restore() => Completer<RestoreOutcome>().future;
}

/// Remote Config that fails on every call.
class _ThrowingConfig implements RemoteConfigSource {
  @override
  Future<void> activateCached() async => throw _down('config');

  @override
  Future<void> fetchForNextLaunch() async => throw _down('config');

  @override
  Object? value(String key) => throw _down('config');
}

/// A review API that fails on every call.
class _ThrowingReview implements ReviewRequester {
  @override
  Future<bool> isAvailable() async => throw _down('review');

  @override
  Future<bool> request() async => throw _down('review');
}

/// Runs [body] with semantics on and releases the handle however it ends.
/// The framework checks for live handles before any tear-down runs, so
/// `addTearDown(handle.dispose)` would come too late.
Future<void> _withSemantics(
  WidgetTester t,
  Future<void> Function() body,
) async {
  final handle = t.ensureSemantics();
  try {
    await body();
  } finally {
    handle.dispose();
  }
}

/// A `testWidgets` that runs with semantics on (see [_withSemantics]).
void _semanticsTest(
  String description,
  Future<void> Function(WidgetTester t) body,
) => testWidgets(description, (t) => _withSemantics(t, () => body(t)));
