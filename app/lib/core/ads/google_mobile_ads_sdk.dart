import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:tv_remote/core/ads/ads_service.dart';

/// [AdsSdk] backed by `google_mobile_ads`.
///
/// This is one of the two files that import it. Every call catches
/// everything, `MissingPluginException` included: a failing platform means no
/// ad, never a crash.
class GoogleMobileAdsSdk implements AdsSdk {
  /// Creates the adapter. It touches the platform only when a method is
  /// called.
  GoogleMobileAdsSdk();

  @override
  Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize();
    } on Object catch (error) {
      _log('ads initialisation failed', error);
    }
  }

  @override
  Future<AdBannerSize?> bannerSize(Orientation orientation, int width) async {
    try {
      final size =
          await AdSize.getLargeAnchoredAdaptiveBannerAdSizeWithOrientation(
            orientation,
            width,
          );
      return size == null
          ? null
          : AdBannerSize(width: size.width, height: size.height);
    } on Object catch (error) {
      _log('banner size failed', error);
      return null;
    }
  }

  @override
  Future<LoadedBanner?> loadBanner(String unitId, AdBannerSize size) async {
    try {
      final done = Completer<BannerAd?>();
      final ad = BannerAd(
        adUnitId: unitId,
        size: AdSize(width: size.width, height: size.height),
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (!done.isCompleted) done.complete(ad as BannerAd);
          },
          onAdFailedToLoad: (ad, error) {
            _log('banner failed to load', error.message);
            unawaited(ad.dispose());
            if (!done.isCompleted) done.complete();
          },
        ),
      );
      await ad.load();
      final loaded = await done.future;
      return loaded == null ? null : _Banner(loaded);
    } on Object catch (error) {
      _log('banner load failed', error);
      return null;
    }
  }

  @override
  Future<LoadedInterstitial?> loadInterstitial(String unitId) async {
    try {
      final done = Completer<InterstitialAd?>();
      await InterstitialAd.load(
        adUnitId: unitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            if (!done.isCompleted) done.complete(ad);
          },
          onAdFailedToLoad: (error) {
            _log('interstitial failed to load', error.message);
            if (!done.isCompleted) done.complete();
          },
        ),
      );
      final loaded = await done.future;
      return loaded == null ? null : _Interstitial(loaded);
    } on Object catch (error) {
      _log('interstitial load failed', error);
      return null;
    }
  }
}

void _log(String what, Object? error) =>
    developer.log(what, name: 'ads', error: error);

/// Disposes [ad] without waiting and without letting a failure escape.
void _release(Ad ad, String what) {
  unawaited(
    Future.sync(ad.dispose).then<void>(
      (_) {},
      onError: (Object error) => _log(what, error),
    ),
  );
}

class _Banner implements LoadedBanner {
  _Banner(this._ad);

  final BannerAd _ad;

  @override
  Widget get widget => AdWidget(ad: _ad);

  @override
  void dispose() => _release(_ad, 'banner dispose failed');
}

class _Interstitial implements LoadedInterstitial {
  _Interstitial(this._ad);

  final InterstitialAd _ad;

  @override
  Future<void> show() async {
    final closed = Completer<void>();
    void finish() {
      if (!closed.isCompleted) closed.complete();
    }

    try {
      _ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
        onAdDismissedFullScreenContent: (_) => finish(),
        onAdFailedToShowFullScreenContent: (_, error) {
          _log('interstitial failed to show', error.message);
          finish();
        },
      );
      await _ad.show();
      await closed.future;
    } on Object catch (error) {
      _log('interstitial show failed', error);
    }
  }

  @override
  void dispose() => _release(_ad, 'interstitial dispose failed');
}
