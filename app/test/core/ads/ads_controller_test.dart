import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/core/ads/ad_placement.dart';
import 'package:tv_remote/core/ads/ad_unit_ids.dart';
import 'package:tv_remote/core/ads/ads_service.dart';
import 'package:tv_remote/core/ads/consent_controller.dart';
import 'package:tv_remote/core/ads/consent_service.dart';
import 'package:tv_remote/core/ads/tracking_service.dart';
import 'package:tv_remote/core/config/app_config.dart';
import 'package:tv_remote/core/purchases/premium.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';

import '../../helpers/fake_ads_sdk.dart';
import '../../helpers/fake_config_source.dart';
import '../../helpers/fake_consent_service.dart';
import '../../helpers/fake_tracking_service.dart';
import '../../helpers/test_premium.dart';

/// A consent service whose every call throws, as when the plugin is missing.
class _ThrowingConsentService implements ConsentService {
  @override
  Future<ConsentRegion> requestUpdate() async =>
      throw MissingPluginException('ump');

  @override
  Future<ConsentFormOutcome> showFormIfRequired() async =>
      throw StateError('form');

  @override
  Future<bool> canRequestAds() async => throw StateError('can');

  @override
  Future<bool> privacyOptionsRequired() async => throw StateError('options');

  @override
  Future<bool> showPrivacyOptions() async => throw StateError('show');
}

void main() {
  late SettingsStore store;
  late FakeAdsSdk sdk;
  late FakeConsentService consent;
  late FakeTrackingService tracking;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    store = await SettingsStore.open();
    sdk = FakeAdsSdk();
    consent = FakeConsentService();
    tracking = FakeTrackingService();
  });

  ProviderContainer containerFor({
    ConsentService? service,
    PremiumState premium = PremiumState.free,
    Map<String, Object?> config = const {},
  }) => ProviderContainer.test(
    overrides: [
      settingsStoreProvider.overrideWithValue(store),
      adUnitIdsProvider.overrideWithValue(
        const AdUnitIds(banner: AdMobTestIds.androidBanner),
      ),
      consentServiceProvider.overrideWithValue(service ?? consent),
      trackingServiceProvider.overrideWithValue(tracking),
      adsSdkProvider.overrideWithValue(sdk),
      premiumProvider.overrideWith(() => TestPremium(premium)),
      remoteConfigSourceProvider.overrideWithValue(FakeConfigSource(config)),
    ],
  );

  /// What the remote screen does: gathers consent.
  Future<ConsentResult> gather(ProviderContainer c) =>
      c.read(consentControllerProvider.notifier).ensureGathered();

  /// Lets pending futures run.
  Future<void> turns() async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('ads_not_initialised_before_consent_resolved', () async {
    final hold = Completer<void>();
    consent.holdShowForm = hold;
    final container = containerFor();
    final ads = container.read(adsControllerProvider.notifier);
    final gathered = gather(container);

    var done = false;
    final ready = ads.ready().then((value) {
      done = true;
      return value;
    });
    await turns();
    expect(done, isFalse, reason: 'the consent form is still open');
    expect(sdk.initializeCalls, 0);

    hold.complete();
    await gathered;
    expect(await ready, isTrue);
    expect(sdk.initializeCalls, 1);
    expect(container.read(adsControllerProvider), isTrue);

    // The SDK starts once, however often it is asked.
    expect(await ads.ready(), isTrue);
    expect(await ads.ready(), isTrue);
    expect(sdk.initializeCalls, 1);
  });

  test('ready_alone_never_opens_the_consent_form', () async {
    // Gathering belongs to the remote screen (Ruling P6-C9): asking whether
    // ads are ready never starts the form, and keeps waiting for it.
    final container = containerFor();
    var done = false;
    final ready = container
        .read(adsControllerProvider.notifier)
        .ready()
        .then((value) => done = true);
    await turns();
    expect(consent.showFormCalls, 0);
    expect(done, isFalse);
    expect(sdk.initializeCalls, 0);

    await gather(container);
    await ready;
    expect(consent.showFormCalls, 1, reason: 'only the remote screen asked');
    expect(sdk.initializeCalls, 1);
  });

  test('no_ads_when_consent_denies_ad_requests', () async {
    consent.canRequest = false;
    final container = containerFor();
    await gather(container);
    final ads = container.read(adsControllerProvider.notifier);

    expect(await ads.ready(), isFalse);
    expect(await ads.ready(), isFalse);
    expect(sdk.initializeCalls, 0);
  });

  test('the_sdk_starts_only_after_the_tracking_decision', () async {
    // Ruling P6-C8 / P6-R3: UMP, then ATT, then the SDK.
    tracking.current = TrackingStatus.notDetermined;
    final container = containerFor();
    await gather(container);
    final ads = container.read(adsControllerProvider.notifier);

    expect(await ads.ready(), isFalse);
    expect(sdk.initializeCalls, 0);
    expect(container.read(adsControllerProvider), isFalse);

    await tracking.request();
    expect(await ads.ready(), isTrue);
    expect(sdk.initializeCalls, 1);
    expect(container.read(adsControllerProvider), isTrue);
  });

  test('sdk_failures_mean_no_ads_not_crashes', () async {
    sdk.failInitialize = true;
    final container = containerFor();
    await gather(container);
    final ads = container.read(adsControllerProvider.notifier);
    expect(await ads.ready(), isFalse);
    expect(await ads.ready(), isFalse);

    // A consent platform that throws everywhere leaves ads off too.
    sdk = FakeAdsSdk();
    final broken = containerFor(service: _ThrowingConsentService());
    await gather(broken);
    expect(await broken.read(adsControllerProvider.notifier).ready(), isFalse);
    expect(sdk.initializeCalls, 0);
  });

  group('banner_allowed_now', () {
    Future<bool> allowed(
      PremiumState premium,
      Map<String, Object?> config,
    ) async {
      final c = containerFor(premium: premium, config: config);
      await c.read(appConfigProvider.notifier).load();
      return c
          .read(adsControllerProvider.notifier)
          .bannerAllowedNow(AdPlacement.settings);
    }

    test('free_and_known_with_the_switch_on', () async {
      expect(await allowed(PremiumState.free, {}), isTrue);
    });

    test('not_for_premium_or_while_premium_is_unknown', () async {
      expect(
        await allowed(
          const PremiumState(isPremium: true, known: true, lifetime: true),
          {},
        ),
        isFalse,
      );
      expect(
        await allowed(const PremiumState(isPremium: false, known: false), {}),
        isFalse,
      );
    });

    test('not_without_a_unit_id', () async {
      final c = ProviderContainer.test(
        overrides: [
          settingsStoreProvider.overrideWithValue(store),
          adUnitIdsProvider.overrideWithValue(const AdUnitIds()),
          premiumProvider.overrideWith(() => TestPremium(PremiumState.free)),
        ],
      );
      expect(
        c
            .read(adsControllerProvider.notifier)
            .bannerAllowedNow(AdPlacement.apps),
        isFalse,
      );
    });

    test('not_with_the_kill_switch_off', () async {
      expect(
        await allowed(PremiumState.free, {'ads_banner_enabled': false}),
        isFalse,
      );
    });
  });
}
