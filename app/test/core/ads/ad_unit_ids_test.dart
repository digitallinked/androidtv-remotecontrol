import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/flavor.dart';
import 'package:tv_remote/core/ads/ad_unit_ids.dart';
import 'package:tv_remote/core/config/service_config.dart';

void main() {
  // Arbitrary ids: resolve() passes the defines through untouched, and no
  // AdMob-shaped id may be committed (ads_config_test scans for them).
  const defined = ServiceConfig(
    admobBannerAndroid: 'prod-banner-android',
    admobBannerIos: 'prod-banner-ios',
    admobInterstitialAndroid: 'prod-interstitial-android',
    admobInterstitialIos: 'prod-interstitial-ios',
  );

  AdUnitIds resolve(
    Flavor flavor,
    TargetPlatform platform, [
    ServiceConfig config = ServiceConfig.none,
  ]) => AdUnitIds.resolve(flavor: flavor, platform: platform, config: config);

  test('dev_always_uses_google_test_ids', () {
    for (final config in [ServiceConfig.none, defined]) {
      final android = resolve(Flavor.dev, TargetPlatform.android, config);
      expect(android.banner, AdMobTestIds.androidBanner);
      expect(android.interstitial, AdMobTestIds.androidInterstitial);
      final ios = resolve(Flavor.dev, TargetPlatform.iOS, config);
      expect(ios.banner, AdMobTestIds.iosBanner);
      expect(ios.interstitial, AdMobTestIds.iosInterstitial);
    }
  });

  test('prod_uses_the_defines_or_nothing', () {
    final android = resolve(Flavor.prod, TargetPlatform.android, defined);
    expect(android.banner, 'prod-banner-android');
    expect(android.interstitial, 'prod-interstitial-android');
    final ios = resolve(Flavor.prod, TargetPlatform.iOS, defined);
    expect(ios.banner, 'prod-banner-ios');
    expect(ios.interstitial, 'prod-interstitial-ios');

    // An empty define is no ad of that kind, never a test id.
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      final none = resolve(Flavor.prod, platform);
      expect(none.banner, isNull);
      expect(none.interstitial, isNull);
    }
    // Banner only: the interstitial stays off.
    final bannerOnly = resolve(
      Flavor.prod,
      TargetPlatform.android,
      const ServiceConfig(admobBannerAndroid: 'prod-banner-only'),
    );
    expect(bannerOnly.banner, 'prod-banner-only');
    expect(bannerOnly.interstitial, isNull);
  });

  test('platforms_without_ads_get_none', () {
    for (final flavor in Flavor.values) {
      final ids = resolve(flavor, TargetPlatform.windows, defined);
      expect(ids.banner, isNull);
      expect(ids.interstitial, isNull);
    }
  });

  test('test_ids_are_googles', () {
    expect(AdMobTestIds.all, hasLength(6));
    for (final id in AdMobTestIds.all) {
      expect(id, startsWith('ca-app-pub-3940256099942544'));
    }
    expect(AdMobTestIds.all.toSet(), {
      AdMobTestIds.androidAppId,
      AdMobTestIds.iosAppId,
      AdMobTestIds.androidBanner,
      AdMobTestIds.iosBanner,
      AdMobTestIds.androidInterstitial,
      AdMobTestIds.iosInterstitial,
    });
  });
}
