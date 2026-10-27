import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/app/flavor.dart';
import 'package:tv_remote/core/ads/ad_unit_ids.dart';
import 'package:tv_remote/core/ads/banner_slot.dart';
import 'package:tv_remote/core/ads/consent_controller.dart';
import 'package:tv_remote/core/ads/google_mobile_ads_sdk.dart';
import 'package:tv_remote/core/config/app_config.dart';
import 'package:tv_remote/core/config/service_config.dart';
import 'package:tv_remote/core/purchases/premium.dart';

part 'ads_service.g.dart';

/// The size of a banner the ads SDK picked for the screen.
@immutable
class AdBannerSize {
  /// Creates a size in logical pixels.
  const AdBannerSize({required this.width, required this.height});

  /// Width in logical pixels.
  final int width;

  /// Height in logical pixels.
  final int height;

  @override
  bool operator ==(Object other) =>
      other is AdBannerSize && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => 'AdBannerSize($width x $height)';
}

/// A banner that has loaded. Whoever holds it disposes it.
abstract interface class LoadedBanner {
  /// The view to put in the tree, once, at the size it was loaded for.
  Widget get widget;

  /// Releases the ad. The [widget] must not be in the tree afterwards.
  void dispose();
}

/// An interstitial that has loaded and has not been shown.
abstract interface class LoadedInterstitial {
  /// Shows the ad full screen. Completes when it is closed, or when it could
  /// not be shown. Never throws.
  Future<void> show();

  /// Releases the ad.
  void dispose();
}

/// The ads SDK behind our own interface. The only code that talks to the
/// vendor package is `google_mobile_ads_sdk.dart`.
///
/// No method throws: a failure is `null`.
abstract interface class AdsSdk {
  /// Starts the SDK. Callers wait for consent first.
  Future<void> initialize();

  /// The large anchored adaptive banner size for [width] logical pixels in
  /// [orientation], or `null` when the SDK can't say.
  Future<AdBannerSize?> bannerSize(Orientation orientation, int width);

  /// Loads a banner of [size], or `null` when it fails.
  Future<LoadedBanner?> loadBanner(String unitId, AdBannerSize size);

  /// Loads an interstitial, or `null` when it fails.
  Future<LoadedInterstitial?> loadInterstitial(String unitId);
}

/// The app's [AdsSdk]: Google Mobile Ads.
@Riverpod(keepAlive: true)
AdsSdk adsSdk(Ref ref) => GoogleMobileAdsSdk();

/// The ad unit ids of this build, flavor and platform.
@Riverpod(keepAlive: true)
AdUnitIds adUnitIds(Ref ref) => AdUnitIds.resolve(
  flavor: ref.watch(flavorProvider),
  platform: defaultTargetPlatform,
  config: ref.watch(serviceConfigProvider),
);

/// Decides when the ads SDK may start and when a banner may show (Ruling
/// P6-R9).
@Riverpod(keepAlive: true)
class AdsController extends _$AdsController {
  Future<void>? _initialised;

  @override
  void build() {}

  /// Whether ads may load: consent has been gathered, the platform allows ad
  /// requests, and the SDK has started. The SDK starts once, and never before
  /// the consent step has finished. Never throws; any failure is `false`.
  Future<bool> ready() async {
    // Read before the first await: the caller (a screen) doesn't wait on a
    // container that has been disposed.
    final consent = ref.read(consentControllerProvider.notifier);
    final sdk = ref.read(adsSdkProvider);
    try {
      await consent.ensureGathered();
      if (!ref.mounted) return false;
      if (!ref.read(consentControllerProvider).canRequestAds) return false;
      await (_initialised ??= sdk.initialize());
      return true;
    } on Object catch (error) {
      developer.log('ads could not start', name: 'ads', error: error);
      return false;
    }
  }

  /// Whether a banner may show on [placement] right now: there is a unit id,
  /// the kill switch is on, and the user is known not to have Premium.
  ///
  /// Both placements follow the same rules.
  bool bannerAllowedNow(AdPlacement placement) {
    final premium = ref.read(premiumProvider);
    return ref.read(adUnitIdsProvider).banner != null &&
        ref.read(appConfigProvider).adsBannerEnabled &&
        premium.known &&
        !premium.isPremium;
  }
}
