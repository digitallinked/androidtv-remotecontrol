import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/widgets/app_dialog.dart';
import 'package:tv_remote/app/widgets/app_key_button.dart';
import 'package:tv_remote/core/ads/ads_service.dart';
import 'package:tv_remote/core/ads/consent_controller.dart';
import 'package:tv_remote/core/ads/consent_service.dart';
import 'package:tv_remote/core/analytics/app_analytics.dart';
import 'package:tv_remote/core/config/app_config.dart';
import 'package:tv_remote/core/crash/crash_reporter.dart';
import 'package:tv_remote/core/purchases/premium.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/discovery/data/discovery_providers.dart';
import 'package:tv_remote/features/discovery/presentation/discovery_screen.dart';
import 'package:tv_remote/features/onboarding/presentation/onboarding_screen.dart';
import 'package:tv_remote/features/remote/presentation/remote_screen.dart';
import 'package:tv_remote/features/remote/presentation/widgets/touchpad.dart';
import 'package:tv_remote/features/settings/presentation/help_page.dart';
import 'package:tv_remote/features/settings/presentation/privacy_choices_page.dart';
import 'package:tv_remote/features/settings/presentation/settings_screen.dart';

import '../helpers/failing_preferences.dart';
import '../helpers/fake_ads_sdk.dart';
import '../helpers/fake_consent_service.dart';
import '../helpers/fake_tv_discovery.dart';
import '../helpers/in_memory_device_repository.dart';
import '../helpers/pump_router_app.dart';
import '../helpers/recording_analytics_sink.dart';
import '../helpers/recording_crash_reporter.dart';
import '../helpers/test_app_config.dart';
import '../helpers/test_devices.dart';
import '../platform/branding_test.dart' as branding;

/// A Premium notifier whose state can't be read: its build throws.
class _UnreadablePremium extends Premium {
  @override
  PremiumState build() => throw StateError('premium unreadable');
}

/// Seam tests for Phase 7: onboarding, Settings before pairing, the update
/// gate, the Premium consent rule and reduce motion, working together with
/// the real router, screens and providers. Only the TV, the stores (in
/// memory) and the vendor SDKs behind our interfaces are faked.
void main() {
  late RecordingAnalyticsSink sink;
  late RecordingCrashReporter crashes;
  late FakeTvDiscoveries discoveries;
  late FakeAdsSdk ads;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  setUp(() {
    sink = RecordingAnalyticsSink();
    crashes = RecordingCrashReporter();
    discoveries = FakeTvDiscoveries();
    // Ads that load at once, so "no banner" and "no interstitial" mean the
    // app decided against them.
    ads = FakeAdsSdk(loads: true);
  });

  final banner = find.byKey(const ValueKey('fake_banner'));

  void phone(WidgetTester t) {
    t.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  /// Recording analytics (a bad event throws, as in a debug build), crash
  /// reports, discovery and ads.
  List<Override> recorders() => [
    analyticsSinkProvider.overrideWithValue(sink),
    analyticsDebugBuildProvider.overrideWithValue(true),
    crashReporterProvider.overrideWithValue(crashes),
    tvDiscoveryFactoryProvider.overrideWithValue(discoveries.create),
    adsSdkProvider.overrideWithValue(ads),
  ];

  ProviderContainer containerOf(WidgetTester t) =>
      ProviderScope.containerOf(t.element(find.byType(MaterialApp)));

  Future<void> back(WidgetTester t) async {
    await t.pageBack();
    await t.pumpAndSettle();
  }

  /// After "Try demo": the remote opens, then outlasts the demo's 600 ms
  /// connect delay.
  Future<void> settleDemo(WidgetTester t) async {
    await t.pump();
    await t.pump(const Duration(milliseconds: 700));
    await t.pumpAndSettle();
  }

  testWidgets('first_run_skip_then_settings_then_back_to_discovery', (
    t,
  ) async {
    phone(t);
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final store = await SettingsStore.open();
    final location = await resolveInitialLocation(
      settings: store,
      devices: InMemoryDeviceRepository(),
    );
    expect(location, AppRoutes.onboarding);

    await pumpRealApp(
      t,
      initialLocation: location,
      overrides: [
        ...recorders(),
        settingsStoreProvider.overrideWithValue(store),
      ],
    );
    expect(find.byType(OnboardingScreen), findsOneWidget);

    await t.tap(find.text('Skip'));
    await t.pumpAndSettle();
    expect(find.byType(DiscoveryScreen), findsOneWidget);

    await t.tap(find.byTooltip('Settings'));
    await t.pumpAndSettle();
    expect(
      t.widget<SettingsScreen>(find.byType(SettingsScreen)).fromSetup,
      isTrue,
    );
    await t.tap(find.text('Help'));
    await t.pumpAndSettle();
    expect(find.byType(HelpPage), findsOneWidget);

    await back(t);
    expect(find.byType(SettingsScreen), findsOneWidget);
    await back(t);
    expect(find.byType(DiscoveryScreen), findsOneWidget);
    expect(find.byType(SettingsScreen, skipOffstage: false), findsNothing);

    // Before pairing: no interstitial on the way back, and no banner.
    expect(ads.shows, 0);
    expect(banner, findsNothing);
    expect(find.text('Advertisement'), findsNothing);
    expect(t.takeException(), isNull);

    expect(
      sink.eventNames.where((e) => e == 'onboarding_complete'),
      hasLength(1),
    );
    expect(sink.screens, isNotEmpty);
    for (final screen in sink.screens) {
      expect(AppRouteNames.all, contains(screen));
    }
    expect(
      sink.screens,
      containsAllInOrder([
        AppRouteNames.onboarding,
        AppRouteNames.discover,
        AppRouteNames.settings,
        AppRouteNames.settingsHelp,
      ]),
    );
  });

  testWidgets('first_run_try_demo_reaches_a_working_remote', (t) async {
    phone(t);
    final handle = t.ensureSemantics();
    try {
      await pumpRealApp(
        t,
        initialLocation: AppRoutes.onboarding,
        overrides: recorders(),
      );
      await t.tap(find.text('Try demo'));
      await settleDemo(t);

      expect(find.byType(RemoteScreen), findsOneWidget);
      expect(find.text('Demo mode'), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
      expect(find.textContaining('Volume 8 of 20'), findsOneWidget);

      await t.tap(find.bySemanticsLabel('Volume up'));
      await t.pump();
      expect(find.textContaining('Volume 9 of 20'), findsOneWidget);
      expect(find.text('Pressed Volume up'), findsOneWidget);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(sink.eventNames.where((e) => e == 'onboarding_complete'), [
        'onboarding_complete',
      ]);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('a_storage_failure_never_traps_the_user', (t) async {
    phone(t);
    // Every write fails from the start; reads work. The store keeps the
    // platform it opened on.
    SharedPreferencesAsyncPlatform.instance = FailingSharedPreferencesAsync();
    final store = await SettingsStore.open();
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.onboarding,
      overrides: [
        ...recorders(),
        settingsStoreProvider.overrideWithValue(store),
      ],
    );

    for (var i = 0; i < 2; i++) {
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
    }
    await t.tap(find.text('Get started'));
    await t.pumpAndSettle();
    expect(find.byType(DiscoveryScreen), findsOneWidget);

    await t.tap(find.byTooltip('Settings'));
    await t.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(t.takeException(), isNull);
    expect(crashes.errors.map((e) => e.reason), contains('onboarding write'));
  });

  testWidgets('premium_in_the_eea_gets_no_consent_form_and_no_ads', (
    t,
  ) async {
    phone(t);
    final consent = FakeConsentService(
      region: ConsentRegion.required,
      formOutcome: ConsentFormOutcome.shown,
      optionsRequired: true,
    );
    final devices = InMemoryDeviceRepository([savedTv()]);
    await pumpRealApp(
      t,
      initialLocation: AppRoutes.remote,
      // Premium as the phone last saw it; the store hasn't answered.
      prepareSettings: (store) async {
        await store.setOnboardingComplete(true);
        await store.setCachedPremium((active: true, expiresAt: null));
      },
      overrides: [
        ...recorders(),
        consentServiceProvider.overrideWithValue(consent),
        deviceRepositoryProvider.overrideWithValue(devices),
        savedDevicesProvider.overrideWith(
          (ref) => ref.watch(deviceRepositoryProvider).watchAll(),
        ),
      ],
    );
    expect(find.byType(RemoteScreen), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
    final container = containerOf(t);
    expect(container.read(premiumProvider).isPremium, isTrue);

    // /remote gathers consent: the silent update runs, the form doesn't.
    final result = container.read(consentControllerProvider);
    expect(result.gathered, isTrue);
    expect(result.formShown, isFalse);
    expect(consent.requestUpdateCalls, greaterThanOrEqualTo(1));
    expect(consent.showFormCalls, 0);

    await t.tap(find.byTooltip('Settings'));
    await t.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(banner, findsNothing);
    expect(find.text('Advertisement'), findsNothing);

    await t.tap(find.text('Privacy choices'));
    await t.pumpAndSettle();
    expect(find.byType(PrivacyChoicesPage), findsOneWidget);
    await t.scrollUntilVisible(
      find.text('Ad privacy choices'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Ad privacy choices'), findsOneWidget);

    await back(t);
    await back(t);
    expect(find.byType(RemoteScreen), findsOneWidget);
    expect(ads.shows, 0);
    expect(ads.bannerLoads, 0);
    expect(consent.showFormCalls, 0);
    expect(t.takeException(), isNull);
  });

  test(
    'an_unreadable_premium_counts_as_free_so_the_consent_form_shows',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final store = await SettingsStore.open();
      final consent = FakeConsentService(
        region: ConsentRegion.required,
        formOutcome: ConsentFormOutcome.shown,
      );
      final container = ProviderContainer.test(
        overrides: [
          settingsStoreProvider.overrideWithValue(store),
          consentServiceProvider.overrideWithValue(consent),
          premiumProvider.overrideWith(_UnreadablePremium.new),
        ],
      )..listen(consentControllerProvider, (_, _) {});

      final result = await container
          .read(consentControllerProvider.notifier)
          .ensureGathered();

      expect(consent.showFormCalls, 1);
      expect(result.gathered, isTrue);
      expect(result.formShown, isTrue);
    },
  );

  testWidgets('back_from_the_no_tv_settings_returns_to_the_no_tv_remote', (
    t,
  ) async {
    phone(t);
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.remote,
      overrides: recorders(),
    );
    expect(find.text('No TV selected'), findsOneWidget);

    await t.tap(find.byTooltip('Settings'));
    await t.pumpAndSettle();
    expect(
      t.widget<SettingsScreen>(find.byType(SettingsScreen)).fromSetup,
      isTrue,
    );

    await back(t);
    expect(find.byType(SettingsScreen, skipOffstage: false), findsNothing);
    expect(find.text('No TV selected'), findsOneWidget);
    expect(find.text('Choose a TV'), findsOneWidget);
    expect(ads.shows, 0);
  });

  testWidgets('forced_update_still_blocks_onboarding_and_discovery', (
    t,
  ) async {
    phone(t);
    for (final route in [AppRoutes.onboarding, AppRoutes.discover]) {
      await pumpRouterApp(
        t,
        initialLocation: route,
        settle: false,
        overrides: [
          ...recorders(),
          appConfigProvider.overrideWith(
            () => TestAppConfig({'min_supported_version': '9.0.0'}),
          ),
        ],
      );
      // The first frame already shows the gate, and nothing behind it.
      expect(find.text('Update required'), findsOneWidget, reason: route);
      expect(find.byType(OnboardingScreen), findsNothing, reason: route);
      expect(find.byType(DiscoveryScreen), findsNothing, reason: route);
      await t.pumpAndSettle();
      expect(find.text('Update required'), findsOneWidget, reason: route);
      expect(find.byType(OnboardingScreen), findsNothing, reason: route);
      expect(find.byType(DiscoveryScreen), findsNothing, reason: route);
    }
  });

  /// Walks onboarding, discovery, Settings, a sheet, the demo remote and a
  /// dialog under reduce motion. After every step one `pump()` draws the
  /// result, and nothing is left animating.
  Future<void> sweep(WidgetTester t, {required bool platformFlag}) async {
    phone(t);
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.onboarding,
      disableAnimations: !platformFlag,
      overrides: recorders(),
    );

    void still(String step) {
      expect(t.hasRunningAnimations, isFalse, reason: step);
      expect(t.takeException(), isNull, reason: step);
    }

    // Onboarding Next.
    await t.tap(find.text('Next'));
    await t.pump();
    expect(find.text('Control it from your phone'), findsOneWidget);
    still('onboarding next');

    // Skip to discovery.
    await t.tap(find.text('Skip'));
    await t.pump();
    expect(find.byType(DiscoveryScreen), findsOneWidget);
    expect(
      find.byType(OnboardingScreen),
      findsNothing,
      reason: 'skip: the page changes in one frame',
    );
    expect(
      ModalRoute.of(t.element(find.byType(DiscoveryScreen)))!.animation!.value,
      1,
      reason: 'skip',
    );
    // While it searches, discovery shows a progress spinner, which is exempt
    // (Ruling P7-R4); nothing else may move.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    discoveries.created.last.emit([tv('Living Room TV 3')]);
    await t.pump();
    expect(find.text('Living Room TV 3'), findsOneWidget);
    still('a tv found');

    // A held press on a list row: its ink highlight appears at once, and
    // goes at once when the press is cancelled.
    final hold = await t.startGesture(
      t.getCenter(find.text('Living Room TV 3')),
    );
    await t.pump();
    still('row pressed');
    await hold.cancel();
    await t.pump();
    still('row press cancelled');

    // Discovery → Settings, and back.
    await t.tap(find.byTooltip('Settings'));
    await t.pump();
    expect(find.byType(SettingsScreen), findsOneWidget);
    still('settings push');
    await t.tap(find.byTooltip('Back'));
    await t.pump();
    expect(find.byType(SettingsScreen, skipOffstage: false), findsNothing);
    still('settings pop');

    // A sheet: Enter IP address.
    await t.tap(find.text('Enter IP address'));
    await t.pump();
    expect(find.byType(BottomSheet), findsOneWidget);
    still('manual ip sheet');
    await t.tap(find.byTooltip('Close'));
    await t.pump();
    expect(find.byType(BottomSheet), findsNothing);
    still('manual ip sheet closed');

    // The demo remote: its status changes from connecting to connected.
    await t.tap(find.text('Try demo'));
    await t.pump();
    expect(find.byType(RemoteScreen), findsOneWidget);
    await t.pump(const Duration(milliseconds: 700));
    await t.pump();
    expect(find.text('Connected'), findsOneWidget);
    still('status change');

    // A key press.
    final press = await t.startGesture(
      t.getCenter(
        find.byWidgetPredicate(
          (w) => w is AppKeyButton && w.semanticLabel == 'Volume up',
        ),
      ),
    );
    await t.pump();
    still('key down');
    await press.up();
    await t.pump();
    expect(find.text('Pressed Volume up'), findsOneWidget);
    still('key up');

    // A touchpad tap.
    await t.tap(find.byType(Touchpad));
    await t.pump();
    still('touchpad tap');

    // A dialog: leave the demo? Stay.
    await t.tap(find.text('Leave'));
    await t.pump();
    expect(find.byType(AppDialog<bool>), findsOneWidget);
    still('dialog');
    await t.tap(find.text('Stay'));
    await t.pump();
    expect(find.byType(AppDialog<bool>), findsNothing);
    still('dialog closed');
  }

  testWidgets('no_animation_runs_anywhere_with_reduce_motion', (t) async {
    await sweep(t, platformFlag: false);
  });

  testWidgets(
    'no_animation_runs_anywhere_with_reduce_motion_from_the_platform',
    (t) async {
      t.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await sweep(t, platformFlag: true);
    },
  );

  // Re-runs the branding checks of test/platform/branding_test.dart for the
  // phase exit.
  group('branding_checks_still_pass', branding.main);
}
