import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/core/ads/ad_unit_ids.dart';
import 'package:tv_remote/core/ads/ads_service.dart';
import 'package:tv_remote/core/ads/banner_slot.dart';
import 'package:tv_remote/core/ads/consent_service.dart';
import 'package:tv_remote/core/config/app_config.dart';
import 'package:tv_remote/core/purchases/premium.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';

import '../../helpers/fake_ads_sdk.dart';
import '../../helpers/fake_config_source.dart';
import '../../helpers/fake_consent_service.dart';
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

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    store = await SettingsStore.open();
    sdk = FakeAdsSdk();
    consent = FakeConsentService();
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
      adsSdkProvider.overrideWithValue(sdk),
      premiumProvider.overrideWith(() => TestPremium(premium)),
      remoteConfigSourceProvider.overrideWithValue(FakeConfigSource(config)),
    ],
  );

  test('ads_not_initialised_before_consent_resolved', () async {
    final hold = Completer<void>();
    consent.holdShowForm = hold;
    final container = containerFor();
    final ads = container.read(adsControllerProvider.notifier);

    var done = false;
    final ready = ads.ready().then((value) {
      done = true;
      return value;
    });
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(done, isFalse, reason: 'the consent form is still open');
    expect(sdk.initializeCalls, 0);

    hold.complete();
    expect(await ready, isTrue);
    expect(sdk.initializeCalls, 1);

    // The SDK starts once, however often it is asked.
    expect(await ads.ready(), isTrue);
    expect(await ads.ready(), isTrue);
    expect(sdk.initializeCalls, 1);
  });

  test('no_ads_when_consent_denies_ad_requests', () async {
    consent.canRequest = false;
    final ads = containerFor().read(adsControllerProvider.notifier);

    expect(await ads.ready(), isFalse);
    expect(await ads.ready(), isFalse);
    expect(sdk.initializeCalls, 0);
  });

  test('sdk_failures_mean_no_ads_not_crashes', () async {
    sdk.failInitialize = true;
    final ads = containerFor().read(adsControllerProvider.notifier);
    expect(await ads.ready(), isFalse);
    expect(await ads.ready(), isFalse);

    // A consent platform that throws everywhere leaves ads off too.
    sdk = FakeAdsSdk();
    final broken = containerFor(service: _ThrowingConsentService());
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
