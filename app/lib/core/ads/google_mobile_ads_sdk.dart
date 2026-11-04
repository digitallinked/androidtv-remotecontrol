import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:tv_remote/core/ads/ads_service.dart';
import 'package:tv_remote/core/crash/crash_reporter.dart';
import 'package:tv_remote/core/crash/error_handlers.dart';

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

/// Starts a load that reports through [start]'s callbacks, waits for the
/// first answer and returns the loaded ad wrapped by [wrap], or `null`.
///
/// The SDK's `load` returns before it answers: the ad arrives later, through
/// the callback. So the ad is read only once the gate has said it loaded. An
/// ad that arrives after the timeout, or that [wrap] fails on, is handed to
/// [discard], so nothing leaks.
@visibleForTesting
Future<R?> loadThroughGate<T extends Object, R extends Object>({
  required Future<void> Function(
    void Function(T ad) onLoaded,
    void Function() onFailed,
  )
  start,
  required R Function(T ad) wrap,
  required void Function(T ad) discard,
  Duration timeout = adLoadTimeout,
}) async {
  final gate = AdLoadGate();
  T? loaded;
  try {
    await start((ad) {
      if (gate.succeed()) {
        loaded = ad;
      } else {
        // It answered after the timeout: nobody is waiting for it.
        discard(ad);
      }
    }, gate.fail);
    if (await gate.result(timeout)) {
      // Read now, not before the wait: `start` returns before the ad does.
      final ad = loaded;
      if (ad != null) {
        try {
          return wrap(ad);
        } on Object {
          discard(ad);
          rethrow;
        }
      }
    }
  } on Object catch (error) {
    _log('ad load failed', error);
    gate.fail();
  }
  return null;
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
    this.configureRequests = _configureRequests,
    this.startSdk = _startSdk,
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

  /// `MobileAds.instance.updateRequestConfiguration`.
  final Future<void> Function(RequestConfiguration configuration)
  configureRequests;

  /// `MobileAds.instance.initialize`.
  final Future<void> Function() startSdk;

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

  static Future<void> _configureRequests(RequestConfiguration configuration) =>
      MobileAds.instance.updateRequestConfiguration(configuration);

  static Future<void> _startSdk() => MobileAds.instance.initialize();
}

/// The request settings every ad is loaded with: the content is capped at G
/// ("general audiences"), because the app is rated 4+ / Everyone and both
/// stores want its ads to suit that rating (Ruling P9-C12). The AdMob
/// console has the same cap; this keeps it if the console setting changes.
@visibleForTesting
final RequestConfiguration adRequestConfiguration = RequestConfiguration(
  maxAdContentRating: MaxAdContentRating.g,
);

/// The crash-report reason when the G content cap can't be set.
const String adsContentCapReason = 'ads content cap';

/// [AdsSdk] backed by `google_mobile_ads`.
///
/// This is one of the two files that import it. Every call catches
/// everything, `MissingPluginException` included: a failing platform means no
/// ad, never a crash.
class GoogleMobileAdsSdk implements AdsSdk {
  /// Creates the adapter. It touches the platform only when a method is
  /// called.
  GoogleMobileAdsSdk({
    this.platform = const GoogleAdsPlatform(),
    this.onContentCapFailure,
  });

  /// The adapter the app uses: a failure to set the G cap reaches [reporter]
  /// as one non-fatal with the reason [adsContentCapReason] (Ruling P9-C13).
  factory GoogleMobileAdsSdk.reportingTo(
    CrashReporter reporter, {
    GoogleAdsPlatform platform = const GoogleAdsPlatform(),
  }) => GoogleMobileAdsSdk(
    platform: platform,
    onContentCapFailure: (error, stack) => safeRecordError(
      reporter,
      error,
      stack,
      reason: adsContentCapReason,
    ),
  );

  /// Called once when [initialize] can't set [adRequestConfiguration], so
  /// the SDK stays off and no ad loads. It must not throw.
  final Future<void> Function(Object error, StackTrace stack)?
  onContentCapFailure;

  /// The vendor calls; only a test replaces them.
  @visibleForTesting
  final GoogleAdsPlatform platform;

  /// The vendor size behind each [AdBannerSize] handed out. A banner must be
  /// requested with the SDK's own adaptive size object: a plain `AdSize`
  /// built from its width and height is sent to the platform as a custom
  /// size, and the orientation and "large" of the adaptive size are lost.
  final Map<AdBannerSize, AnchoredAdaptiveBannerAdSize> _sizes = {};

  /// Whether [initialize] could not set [adRequestConfiguration]. Then no ad
  /// is loaded at all: an ad without the G cap could exceed the app's rating.
  bool _uncapped = false;

  /// Sets [adRequestConfiguration], then starts the SDK. It runs after the
  /// consent and tracking steps (decision #41), which the caller orders.
  @override
  Future<void> initialize() async {
    try {
      await platform.configureRequests(adRequestConfiguration);
    } on Object catch (error, stack) {
      _log('ad content rating could not be set; no ads', error);
      _uncapped = true;
      // Never silent (Ruling P9-C13): a whole session without ads is worth
      // one non-fatal report.
      await onContentCapFailure?.call(error, stack);
      return;
    }
    try {
      await platform.startSdk();
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
    if (_uncapped) return null;
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
    if (_uncapped) return null;
    return loadThroughGate<InterstitialAd, LoadedInterstitial>(
      start: (onLoaded, onFailed) => platform.startInterstitial(
        unitId,
        InterstitialAdLoadCallback(
          onAdLoaded: onLoaded,
          onAdFailedToLoad: (error) {
            _log('interstitial failed to load', error.message);
            onFailed();
          },
        ),
      ),
      wrap: (ad) => _Interstitial(ad, platform.releaseAd),
      discard: (ad) => _release(platform.releaseAd, ad, 'interstitial'),
    );
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
