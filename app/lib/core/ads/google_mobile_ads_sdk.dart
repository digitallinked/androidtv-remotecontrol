import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:tv_remote/core/ads/ads_service.dart';

/// How long a banner or an interstitial may take to load before it counts as
/// failed and is released.
const Duration adLoadTimeout = Duration(seconds: 30);

/// The first answer to "did this ad load?", and the one that counts.
///
/// The SDK reports through listeners that stay attached for the ad's whole
/// life: a banner that refreshes reports `loaded` and, on Android, `failed to
/// load` again, long after the load that [result] answers. Only the first
/// report is the load's; later ones return `false` and must change nothing.
@visibleForTesting
class AdLoadGate {
  final Completer<bool> _done = Completer<bool>();

  /// Whether no answer has come yet.
  bool get isPending => !_done.isCompleted;

  /// The ad loaded. Returns whether this was the answer (`false`: too late).
  bool succeed() {
    if (!isPending) return false;
    _done.complete(true);
    return true;
  }

  /// The ad failed. Returns whether this was the answer: only then does the
  /// caller still own an ad to release.
  bool fail() {
    if (!isPending) return false;
    _done.complete(false);
    return true;
  }

  /// Completes with the answer, or with `false` once [timeout] has passed
  /// without one.
  Future<bool> result(Duration timeout) => _done.future.timeout(
    timeout,
    onTimeout: () {
      fail();
      return false;
    },
  );
}

/// Looks up the large anchored adaptive banner size for a width.
typedef AdSizeLookup =
    Future<AnchoredAdaptiveBannerAdSize?> Function(
      Orientation orientation,
      int width,
    );

/// The vendor calls the adapter makes, so a test can stand in for them.
///
/// The defaults are the real calls.
@visibleForTesting
class GoogleAdsPlatform {
  /// Creates the platform; each part defaults to the real SDK call.
  const GoogleAdsPlatform({
    this.lookupSize = _lookupSize,
    this.startBanner = _startBanner,
    this.startInterstitial = _startInterstitial,
    this.releaseAd = _releaseAd,
  });

  /// `AdSize.getLargeAnchoredAdaptiveBannerAdSizeWithOrientation`.
  final AdSizeLookup lookupSize;

  /// `BannerAd.load`: starts the load; the result comes to the ad's listener.
  final Future<void> Function(BannerAd ad) startBanner;

  /// `InterstitialAd.load`: starts the load; the result comes to the
  /// callback.
  final Future<void> Function(
    String unitId,
    InterstitialAdLoadCallback callback,
  )
  startInterstitial;

  /// `Ad.dispose`.
  final Future<void> Function(Ad ad) releaseAd;

  static Future<AnchoredAdaptiveBannerAdSize?> _lookupSize(
    Orientation orientation,
    int width,
  ) => AdSize.getLargeAnchoredAdaptiveBannerAdSizeWithOrientation(
    orientation,
    width,
  );

  static Future<void> _startBanner(BannerAd ad) => ad.load();

  static Future<void> _startInterstitial(
    String unitId,
    InterstitialAdLoadCallback callback,
  ) => InterstitialAd.load(
    adUnitId: unitId,
    request: const AdRequest(),
    adLoadCallback: callback,
  );

  static Future<void> _releaseAd(Ad ad) => ad.dispose();
}

/// [AdsSdk] backed by `google_mobile_ads`.
///
/// This is one of the two files that import it. Every call catches
/// everything, `MissingPluginException` included: a failing platform means no
/// ad, never a crash.
class GoogleMobileAdsSdk implements AdsSdk {
  /// Creates the adapter. It touches the platform only when a method is
  /// called.
  GoogleMobileAdsSdk({this.platform = const GoogleAdsPlatform()});

  /// The vendor calls; only a test replaces them.
  @visibleForTesting
  final GoogleAdsPlatform platform;

  /// The vendor size behind each [AdBannerSize] handed out. A banner must be
  /// requested with the SDK's own adaptive size object: a plain `AdSize`
  /// built from its width and height is sent to the platform as a custom
  /// size, and the orientation and "large" of the adaptive size are lost.
  final Map<AdBannerSize, AnchoredAdaptiveBannerAdSize> _sizes = {};

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
      final size = await platform.lookupSize(orientation, width);
      if (size == null) return null;
      final ours = AdBannerSize(width: size.width, height: size.height);
      _sizes[ours] = size;
      return ours;
    } on Object catch (error) {
      _log('banner size failed', error);
      return null;
    }
  }

  @override
  Future<LoadedBanner?> loadBanner(String unitId, AdBannerSize size) async {
    final vendorSize = _sizes[size];
    if (vendorSize == null) {
      _log('banner size was not picked by the SDK', size);
      return null;
    }
    final gate = AdLoadGate();
    final ad = BannerAd(
      adUnitId: unitId,
      size: vendorSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => gate.succeed(),
        // Also reported when a later refresh finds no ad. Then the banner is
        // on screen and stays: only a failure of the first load is the end
        // of the ad.
        onAdFailedToLoad: (_, error) {
          _log('banner failed to load', error.message);
          gate.fail();
        },
      ),
    );
    final banner = _Banner(ad, platform.releaseAd);
    try {
      await platform.startBanner(ad);
      if (await gate.result(adLoadTimeout)) return banner;
    } on Object catch (error) {
      _log('banner load failed', error);
      gate.fail();
    }
    banner.dispose();
    return null;
  }

  @override
  Future<LoadedInterstitial?> loadInterstitial(String unitId) async {
    final gate = AdLoadGate();
    InterstitialAd? loaded;
    try {
      await platform.startInterstitial(
        unitId,
        InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            if (gate.succeed()) {
              loaded = ad;
            } else {
              // It answered after the timeout: nobody is waiting for it.
              _release(platform.releaseAd, ad, 'late interstitial');
            }
          },
          onAdFailedToLoad: (error) {
            _log('interstitial failed to load', error.message);
            gate.fail();
          },
        ),
      );
      final ad = loaded;
      if (await gate.result(adLoadTimeout) && ad != null) {
        return _Interstitial(ad, platform.releaseAd);
      }
    } on Object catch (error) {
      _log('interstitial load failed', error);
      gate.fail();
    }
    return null;
  }
}

void _log(String what, Object? error) =>
    developer.log(what, name: 'ads', error: error);

/// Releases [ad] without waiting and without letting a failure escape.
void _release(Future<void> Function(Ad ad) release, Ad ad, String what) {
  unawaited(
    Future.sync(() => release(ad)).then<void>(
      (_) {},
      onError: (Object error) => _log('$what: dispose failed', error),
    ),
  );
}

class _Banner implements LoadedBanner {
  _Banner(this._ad, this._releaseAd);

  final BannerAd _ad;
  final Future<void> Function(Ad ad) _releaseAd;
  bool _disposed = false;

  @override
  Widget get widget => AdWidget(ad: _ad);

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _release(_releaseAd, _ad, 'banner');
  }
}

class _Interstitial implements LoadedInterstitial {
  _Interstitial(this._ad, this._releaseAd);

  final InterstitialAd _ad;
  final Future<void> Function(Ad ad) _releaseAd;
  bool _disposed = false;

  @override
  Future<bool> show() async {
    final closed = Completer<bool>();
    try {
      _ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
        onAdDismissedFullScreenContent: (_) {
          if (!closed.isCompleted) closed.complete(true);
        },
        onAdFailedToShowFullScreenContent: (_, error) {
          _log('interstitial failed to show', error.message);
          if (!closed.isCompleted) closed.complete(false);
        },
      );
      await _ad.show();
      return await closed.future;
    } on Object catch (error) {
      _log('interstitial show failed', error);
      return false;
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _release(_releaseAd, _ad, 'interstitial');
  }
}
