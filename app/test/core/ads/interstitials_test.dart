import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/ads/ad_unit_ids.dart';
import 'package:tv_remote/core/ads/ads_service.dart';
import 'package:tv_remote/core/ads/consent_controller.dart';
import 'package:tv_remote/core/ads/consent_service.dart';
import 'package:tv_remote/core/ads/interstitials.dart';
import 'package:tv_remote/core/ads/tracking_service.dart';
import 'package:tv_remote/core/config/app_config.dart';
import 'package:tv_remote/core/purchases/premium.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/remote/application/remote_actions.dart';

import '../../helpers/fake_ads_sdk.dart';
import '../../helpers/fake_consent_service.dart';
import '../../helpers/fake_remote_session.dart';
import '../../helpers/fake_tracking_service.dart';
import '../../helpers/pump_router_app.dart';
import '../../helpers/test_app_config.dart';
import '../../helpers/test_premium.dart';

const _connected = TvConnectionState(status: ConnectionStatus.connected);
const _offline = TvConnectionState(status: ConnectionStatus.offline);

/// An [Interstitials] that only records the triggers it is asked about.
class _RecordingInterstitials extends Interstitials {
  final List<InterstitialTrigger> triggers = [];

  @override
  Future<bool> maybeShow(InterstitialTrigger trigger) async {
    triggers.add(trigger);
    return false;
  }
}

/// Lets every pending future and zero-delay timer run, without moving the
/// clock.
void settle(FakeAsync async) {
  async
    ..flushMicrotasks()
    ..elapse(Duration.zero);
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late SettingsStore store;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    store = await SettingsStore.open();
    await store.setLaunchCount(2);
  });

  final start = DateTime.utc(2026, 10, 27, 12);

  /// Everything one interstitial test controls. Build it inside `fakeAsync`.
  ({
    ProviderContainer container,
    FakeAdsSdk sdk,
    FakeRemoteSession session,
    FakeConsentService consent,
    Interstitials interstitials,
  })
  rig(
    FakeAsync async, {
    Map<String, Object?> config = const {'ads_interstitial_enabled': true},
    PremiumState premium = PremiumState.free,
    bool demo = false,
    FakeAdsSdk? sdk,
    FakeConsentService? consent,
    TrackingStatus tracking = TrackingStatus.notApplicable,
    bool gather = true,
  }) {
    final fakeSdk = sdk ?? FakeAdsSdk(loads: true);
    final fakeConsent = consent ?? FakeConsentService();
    final session = FakeRemoteSession(isDemo: demo, initial: _connected);
    final container = ProviderContainer.test(
      overrides: [
        settingsStoreProvider.overrideWithValue(store),
        adsSdkProvider.overrideWithValue(fakeSdk),
        adUnitIdsProvider.overrideWithValue(
          const AdUnitIds(
            banner: AdMobTestIds.androidBanner,
            interstitial: AdMobTestIds.androidInterstitial,
          ),
        ),
        consentServiceProvider.overrideWithValue(fakeConsent),
        trackingServiceProvider.overrideWithValue(
          FakeTrackingService(current: tracking),
        ),
        premiumProvider.overrideWith(() => TestPremium(premium)),
        appConfigProvider.overrideWith(() => TestAppConfig(config)),
        remoteSessionProvider.overrideWith((ref) async => session),
      ],
    );
    if (gather) {
      unawaited(
        container.read(consentControllerProvider.notifier).ensureGathered(),
      );
      settle(async);
    }
    // Listened to, as the app does: Riverpod pauses a provider nothing
    // listens to, and its own listeners stop with it.
    container.listen(interstitialsProvider, (_, _) {});
    final interstitials = container.read(interstitialsProvider.notifier);
    settle(async);
    return (
      container: container,
      sdk: fakeSdk,
      session: session,
      consent: fakeConsent,
      interstitials: interstitials,
    );
  }

  /// Runs [maybeShow] to its end and returns the answer.
  bool? show(FakeAsync async, Interstitials interstitials) {
    bool? answer;
    unawaited(
      interstitials
          .maybeShow(InterstitialTrigger.leftSettings)
          .then((v) => answer = v),
    );
    settle(async);
    return answer;
  }

  /// Runs [body] with a fake clock that starts at [start] and moves with
  /// `async.elapse`.
  void timed(void Function(FakeAsync async) body) {
    fakeAsync((async) {
      withClock(async.getClock(start), () => body(async));
    });
  }

  test('interstitial_respects_min_interval', () {
    timed((async) {
      final r = rig(async);
      expect(r.sdk.interstitialLoads, 1, reason: 'preloaded once enabled');

      expect(show(async, r.interstitials), isTrue);
      expect(r.sdk.shows, 1);
      expect(store.interstitialLastShownAt, start);
      expect(r.sdk.interstitialLoads, 2, reason: 'the next one preloads');

      async.elapse(const Duration(seconds: 599));
      expect(show(async, r.interstitials), isFalse);
      expect(r.sdk.shows, 1);

      async.elapse(const Duration(seconds: 1));
      expect(show(async, r.interstitials), isTrue);
      expect(r.sdk.shows, 2);
      expect(
        store.interstitialLastShownAt,
        start.add(const Duration(seconds: 600)),
      );
    });
  });

  test('the_interval_comes_from_remote_config_and_survives_a_restart', () {
    timed((async) {
      final r = rig(
        async,
        config: const {
          'ads_interstitial_enabled': true,
          'ads_interstitial_min_interval_s': 120,
        },
      );
      expect(show(async, r.interstitials), isTrue);

      // A new launch (a new container on the same store) still waits.
      async.elapse(const Duration(seconds: 119));
      final again = rig(
        async,
        config: const {
          'ads_interstitial_enabled': true,
          'ads_interstitial_min_interval_s': 120,
        },
      );
      expect(show(async, again.interstitials), isFalse);
      async.elapse(const Duration(seconds: 1));
      expect(show(async, again.interstitials), isTrue);
    });
  });

  test('interstitial_off_by_default', () {
    timed((async) {
      final r = rig(async, config: const {});
      expect(show(async, r.interstitials), isFalse);
      expect(r.sdk.interstitialLoads, 0);
      expect(r.sdk.initializeCalls, 0);
      expect(r.sdk.shows, 0);
      expect(store.interstitialLastShownAt, isNull);
    });
  });

  group('interstitial_never_for_premium_demo_or_first_launch', () {
    test('premium', () {
      timed((async) {
        final r = rig(
          async,
          premium: const PremiumState(isPremium: true, known: true),
        );
        expect(show(async, r.interstitials), isFalse);
        expect(r.sdk.interstitialLoads, 0);
        expect(r.sdk.shows, 0);
      });
    });

    test('premium_not_known_yet', () {
      timed((async) {
        final r = rig(
          async,
          premium: const PremiumState(isPremium: false, known: false),
        );
        expect(show(async, r.interstitials), isFalse);
        expect(r.sdk.interstitialLoads, 0);
        expect(r.sdk.shows, 0);
      });
    });

    test('demo', () {
      timed((async) {
        final r = rig(async, demo: true);
        expect(show(async, r.interstitials), isFalse);
        expect(r.sdk.shows, 0);
      });
    });

    test('first_launch', () {
      timed((async) {
        unawaited(store.setLaunchCount(1));
        settle(async);
        final r = rig(async);
        expect(show(async, r.interstitials), isFalse);
        expect(r.sdk.interstitialLoads, 0);
        expect(r.sdk.shows, 0);
      });
    });

    test('consent_does_not_allow_ad_requests', () {
      timed((async) {
        final r = rig(async, consent: FakeConsentService(canRequest: false));
        expect(show(async, r.interstitials), isFalse);
        expect(r.sdk.interstitialLoads, 0);
        expect(r.sdk.initializeCalls, 0);
      });
    });
  });

  group('no_ad_request_before_the_user_has_decided', () {
    test('consent_is_still_being_gathered', () {
      timed((async) {
        final hold = Completer<void>();
        final r = rig(
          async,
          consent: FakeConsentService(holdShowForm: hold),
        );
        expect(r.sdk.interstitialLoads, 0);
        expect(r.sdk.initializeCalls, 0);
        expect(show(async, r.interstitials), isFalse);

        hold.complete();
        settle(async);
        expect(r.sdk.initializeCalls, 1);
        expect(r.sdk.interstitialLoads, 1);
        expect(show(async, r.interstitials), isTrue);
      });
    });

    test('ios_tracking_question_is_still_open', () {
      timed((async) {
        final r = rig(async, tracking: TrackingStatus.notDetermined);
        expect(r.sdk.interstitialLoads, 0);
        expect(show(async, r.interstitials), isFalse);
        expect(r.sdk.interstitialLoads, 0);
      });
    });
  });

  test('interstitial_never_within_60s_of_trouble', () {
    timed((async) {
      final r = rig(async);
      async.elapse(const Duration(seconds: 100));

      // A "Not connected" notice 30 s ago.
      r.container.read(notConnectedNoticesProvider.notifier).notify();
      async.elapse(const Duration(seconds: 30));
      expect(show(async, r.interstitials), isFalse);
      expect(r.sdk.shows, 0);

      async.elapse(const Duration(seconds: 31));
      expect(show(async, r.interstitials), isTrue);
      expect(r.sdk.shows, 1);
    });
  });

  test('a_lost_connection_counts_as_trouble_for_60s', () {
    timed((async) {
      final r = rig(async);
      async.elapse(const Duration(seconds: 100));
      r.session.emit(_offline);
      settle(async);

      async.elapse(const Duration(seconds: 59));
      expect(show(async, r.interstitials), isFalse);
      async.elapse(const Duration(seconds: 1));
      expect(show(async, r.interstitials), isTrue);
    });
  });

  test('interstitial_only_when_already_loaded', () {
    timed((async) {
      final hold = Completer<void>();
      final r = rig(
        async,
        sdk: FakeAdsSdk(loads: true)..holdInterstitialLoad = hold,
      );
      expect(r.sdk.interstitialLoads, 1, reason: 'the load has started');

      // The load is pending: no waiting, no ad.
      expect(show(async, r.interstitials), isFalse);
      expect(r.sdk.shows, 0);
      expect(store.interstitialLastShownAt, isNull);

      hold.complete();
      settle(async);
      expect(show(async, r.interstitials), isTrue);
      expect(r.sdk.shows, 1);
    });
  });

  test('a_failed_load_means_no_ad_and_no_crash', () {
    timed((async) {
      final r = rig(async, sdk: FakeAdsSdk(loads: true, failLoads: true));
      expect(show(async, r.interstitials), isFalse);
      expect(r.sdk.shows, 0);
      expect(store.interstitialLastShownAt, isNull);
    });
  });

  test('premium_arriving_stops_interstitials', () {
    timed((async) {
      final premium = TestPremium(PremiumState.free);
      final sdk = FakeAdsSdk(loads: true);
      final container = ProviderContainer.test(
        overrides: [
          settingsStoreProvider.overrideWithValue(store),
          adsSdkProvider.overrideWithValue(sdk),
          adUnitIdsProvider.overrideWithValue(
            const AdUnitIds(interstitial: AdMobTestIds.androidInterstitial),
          ),
          consentServiceProvider.overrideWithValue(FakeConsentService()),
          trackingServiceProvider.overrideWithValue(FakeTrackingService()),
          premiumProvider.overrideWith(() => premium),
          appConfigProvider.overrideWith(
            () => TestAppConfig(const {'ads_interstitial_enabled': true}),
          ),
          remoteSessionProvider.overrideWith(
            (ref) async => FakeRemoteSession(initial: _connected),
          ),
        ],
      );
      unawaited(
        container.read(consentControllerProvider.notifier).ensureGathered(),
      );
      settle(async);
      container.listen(interstitialsProvider, (_, _) {});
      final interstitials = container.read(interstitialsProvider.notifier);
      settle(async);
      expect(sdk.interstitialLoads, 1);

      premium.set(const PremiumState(isPremium: true, known: true));
      settle(async);
      expect(show(async, interstitials), isFalse);
      expect(sdk.shows, 0);
      expect(sdk.interstitialsDisposed, 1, reason: 'the waiting ad is dropped');
    });
  });

  group('leaving_settings_is_the_only_trigger', () {
    testWidgets('leaving_settings_is_the_only_trigger', (t) async {
      final recorder = _RecordingInterstitials();
      await pumpRouterApp(
        t,
        initialLocation: AppRoutes.remote,
        overrides: [interstitialsProvider.overrideWith(() => recorder)],
      );
      unawaited(
        GoRouter.of(
          t.element(find.byType(Scaffold).first),
        ).push<void>(AppRoutes.settings),
      );
      await t.pumpAndSettle();
      expect(recorder.triggers, isEmpty, reason: 'opening is not leaving');

      // Settings → a sub-page → back to the hub: no trigger.
      await t.tap(find.byIcon(Icons.palette_outlined));
      await t.pumpAndSettle();
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.text('Settings'), findsWidgets);
      expect(recorder.triggers, isEmpty, reason: 'a sub-page is not the hub');

      // Leaving the hub is the trigger, once.
      await t.pageBack();
      await t.pumpAndSettle();
      expect(recorder.triggers, [InterstitialTrigger.leftSettings]);
    });

    test('there_is_one_trigger', () {
      expect(InterstitialTrigger.values, [InterstitialTrigger.leftSettings]);
    });
  });
}
