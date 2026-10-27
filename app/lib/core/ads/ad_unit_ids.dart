import 'package:flutter/foundation.dart';
import 'package:tv_remote/app/flavor.dart';
import 'package:tv_remote/core/config/service_config.dart';

/// Google's published test ids (publisher `ca-app-pub-3940256099942544`).
///
/// They serve test creatives only and never earn anything, so they are safe
/// to commit. The app ids are the ones the native builds fall back on.
abstract final class AdMobTestIds {
  /// The Android test app id (`${admobAppId}` in the dev flavor).
  static const androidAppId = 'ca-app-pub-3940256099942544~3347511713';

  /// The iOS test app id (`GADApplicationIdentifier` in the dev configs).
  static const iosAppId = 'ca-app-pub-3940256099942544~1458002511';

  /// The Android adaptive banner test unit.
  static const androidBanner = 'ca-app-pub-3940256099942544/9214589741';

  /// The iOS adaptive banner test unit.
  static const iosBanner = 'ca-app-pub-3940256099942544/2435281174';

  /// The Android interstitial test unit.
  static const androidInterstitial = 'ca-app-pub-3940256099942544/1033173712';

  /// The iOS interstitial test unit.
  static const iosInterstitial = 'ca-app-pub-3940256099942544/4411468910';

  /// Every id above.
  static const all = <String>[
    androidAppId,
    iosAppId,
    androidBanner,
    iosBanner,
    androidInterstitial,
    iosInterstitial,
  ];
}

/// The ad unit ids this build uses on this platform (Ruling P6-R9). A `null`
/// id means "no ad of that kind".
@immutable
class AdUnitIds {
  /// Creates a pair of ids.
  const AdUnitIds({this.banner, this.interstitial});

  /// The ids for [flavor] on [platform].
  ///
  /// [Flavor.dev] always uses Google's test units and ignores the defines in
  /// [config]. [Flavor.prod] uses the defines, and an empty define gives
  /// `null`. Platforms other than Android and iOS have no ads.
  factory AdUnitIds.resolve({
    required Flavor flavor,
    required TargetPlatform platform,
    required ServiceConfig config,
  }) {
    final android = platform == TargetPlatform.android;
    if (!android && platform != TargetPlatform.iOS) return const AdUnitIds();
    if (flavor == Flavor.dev) {
      return AdUnitIds(
        banner: android ? AdMobTestIds.androidBanner : AdMobTestIds.iosBanner,
        interstitial: android
            ? AdMobTestIds.androidInterstitial
            : AdMobTestIds.iosInterstitial,
      );
    }
    String? defined(String value) => value.trim().isEmpty ? null : value.trim();
    return AdUnitIds(
      banner: defined(
        android ? config.admobBannerAndroid : config.admobBannerIos,
      ),
      interstitial: defined(
        android ? config.admobInterstitialAndroid : config.admobInterstitialIos,
      ),
    );
  }

  /// The banner unit, or `null` for no banner.
  final String? banner;

  /// The interstitial unit, or `null` for no interstitial.
  final String? interstitial;

  @override
  bool operator ==(Object other) =>
      other is AdUnitIds &&
      other.banner == banner &&
      other.interstitial == interstitial;

  @override
  int get hashCode => Object.hash(banner, interstitial);

  @override
  String toString() =>
      'AdUnitIds(banner: $banner, interstitial: $interstitial)';
}
