// `environment` reads `fromEnvironment`, which the analyzer evaluates without
// any defines, so it sees every argument there as the default. The private
// `_umpTestDeviceId` cannot be an initializing formal of a public name.
// ignore_for_file: avoid_redundant_argument_values, prefer_initializing_formals

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'service_config.g.dart';

/// The names of the build-time values (`--dart-define-from-file=env/<flavor>.json`).
///
/// They match `env/example.json`, which lists every one with an empty value.
abstract final class ServiceConfigKeys {
  /// Whether to start Firebase at all.
  static const firebaseEnabled = 'FIREBASE_ENABLED';

  /// RevenueCat public SDK key for Android.
  static const revenueCatAndroidKey = 'REVENUECAT_ANDROID_KEY';

  /// RevenueCat public SDK key for iOS.
  static const revenueCatIosKey = 'REVENUECAT_IOS_KEY';

  /// AdMob banner unit id for Android.
  static const admobBannerAndroid = 'ADMOB_BANNER_ANDROID';

  /// AdMob banner unit id for iOS.
  static const admobBannerIos = 'ADMOB_BANNER_IOS';

  /// AdMob interstitial unit id for Android.
  static const admobInterstitialAndroid = 'ADMOB_INTERSTITIAL_ANDROID';

  /// AdMob interstitial unit id for iOS.
  static const admobInterstitialIos = 'ADMOB_INTERSTITIAL_IOS';

  /// UMP debug geography: empty, `eea` or `other` (dev only).
  static const umpDebugGeography = 'UMP_DEBUG_GEOGRAPHY';

  /// UMP test device id (dev only).
  static const umpTestDeviceId = 'UMP_TEST_DEVICE_ID';

  /// Every key, in the order of `env/example.json`.
  static const all = <String>[
    firebaseEnabled,
    revenueCatAndroidKey,
    revenueCatIosKey,
    admobBannerAndroid,
    admobBannerIos,
    admobInterstitialAndroid,
    admobInterstitialIos,
    umpDebugGeography,
    umpTestDeviceId,
  ];
}

/// What this build is configured for. Every value defaults to empty or
/// false, which keeps the matching service off (Ruling P6-R2).
@immutable
class ServiceConfig {
  /// Creates a config; every service is off unless a value is given.
  const ServiceConfig({
    this.firebaseEnabled = false,
    this.revenueCatAndroidKey = '',
    this.revenueCatIosKey = '',
    this.admobBannerAndroid = '',
    this.admobBannerIos = '',
    this.admobInterstitialAndroid = '',
    this.admobInterstitialIos = '',
    this.umpDebugGeography = '',
    String umpTestDeviceId = '',
  }) : _umpTestDeviceId = umpTestDeviceId;

  /// A config with every service off.
  static const ServiceConfig none = ServiceConfig();

  /// The values this build was started with. `fromEnvironment` only works in
  /// a `const` expression, so each value is read here.
  static const ServiceConfig environment = ServiceConfig(
    firebaseEnabled: bool.fromEnvironment(ServiceConfigKeys.firebaseEnabled),
    revenueCatAndroidKey: String.fromEnvironment(
      ServiceConfigKeys.revenueCatAndroidKey,
    ),
    revenueCatIosKey: String.fromEnvironment(
      ServiceConfigKeys.revenueCatIosKey,
    ),
    admobBannerAndroid: String.fromEnvironment(
      ServiceConfigKeys.admobBannerAndroid,
    ),
    admobBannerIos: String.fromEnvironment(ServiceConfigKeys.admobBannerIos),
    admobInterstitialAndroid: String.fromEnvironment(
      ServiceConfigKeys.admobInterstitialAndroid,
    ),
    admobInterstitialIos: String.fromEnvironment(
      ServiceConfigKeys.admobInterstitialIos,
    ),
    umpDebugGeography: String.fromEnvironment(
      ServiceConfigKeys.umpDebugGeography,
    ),
    umpTestDeviceId: String.fromEnvironment(ServiceConfigKeys.umpTestDeviceId),
  );

  /// Whether to start Firebase (`FIREBASE_ENABLED`).
  final bool firebaseEnabled;

  /// RevenueCat key for Android (`REVENUECAT_ANDROID_KEY`).
  final String revenueCatAndroidKey;

  /// RevenueCat key for iOS (`REVENUECAT_IOS_KEY`).
  final String revenueCatIosKey;

  /// Banner unit id for Android (`ADMOB_BANNER_ANDROID`).
  final String admobBannerAndroid;

  /// Banner unit id for iOS (`ADMOB_BANNER_IOS`).
  final String admobBannerIos;

  /// Interstitial unit id for Android (`ADMOB_INTERSTITIAL_ANDROID`).
  final String admobInterstitialAndroid;

  /// Interstitial unit id for iOS (`ADMOB_INTERSTITIAL_IOS`).
  final String admobInterstitialIos;

  /// UMP debug geography (`UMP_DEBUG_GEOGRAPHY`): empty, `eea` or `other`.
  final String umpDebugGeography;

  final String _umpTestDeviceId;

  /// The RevenueCat key for [platform], or `null` when it is not set.
  String? revenueCatKey(TargetPlatform platform) =>
      _nonEmpty(switch (platform) {
        TargetPlatform.iOS => revenueCatIosKey,
        TargetPlatform.android => revenueCatAndroidKey,
        _ => '',
      });

  /// The value for a [ServiceConfigKeys] name, or `null` when it is empty or
  /// false. [ServiceConfigKeys.firebaseEnabled] gives `'true'` or `null`.
  String? define(String key) => switch (key) {
    ServiceConfigKeys.firebaseEnabled => firebaseEnabled ? 'true' : null,
    ServiceConfigKeys.revenueCatAndroidKey => _nonEmpty(revenueCatAndroidKey),
    ServiceConfigKeys.revenueCatIosKey => _nonEmpty(revenueCatIosKey),
    ServiceConfigKeys.admobBannerAndroid => _nonEmpty(admobBannerAndroid),
    ServiceConfigKeys.admobBannerIos => _nonEmpty(admobBannerIos),
    ServiceConfigKeys.admobInterstitialAndroid => _nonEmpty(
      admobInterstitialAndroid,
    ),
    ServiceConfigKeys.admobInterstitialIos => _nonEmpty(admobInterstitialIos),
    ServiceConfigKeys.umpDebugGeography => _nonEmpty(umpDebugGeography),
    ServiceConfigKeys.umpTestDeviceId => umpTestDeviceId,
    _ => null,
  };

  /// Whether the UMP debug geography is forced to the EEA.
  bool get umpDebugEea => umpDebugGeography == 'eea';

  /// The UMP test device id (`UMP_TEST_DEVICE_ID`), or `null` when it is not
  /// set.
  String? get umpTestDeviceId => _nonEmpty(_umpTestDeviceId);

  static String? _nonEmpty(String value) => value.isEmpty ? null : value;
}

/// The build's [ServiceConfig]. Startup overrides it; tests get
/// [ServiceConfig.none].
@Riverpod(keepAlive: true)
ServiceConfig serviceConfig(Ref ref) => ServiceConfig.none;
