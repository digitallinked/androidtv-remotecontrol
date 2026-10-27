import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:tv_remote/core/ads/ads_service.dart';
import 'package:tv_remote/core/ads/google_mobile_ads_sdk.dart';

/// The adaptive size the SDK would answer for a 360 dp wide portrait screen.
AnchoredAdaptiveBannerAdSize _adaptive({
  Orientation orientation = Orientation.portrait,
  int width = 360,
  int height = 90,
}) => AnchoredAdaptiveBannerAdSize(
  orientation,
  width: width,
  height: height,
  isLarge: true,
);

/// A "no fill" error. The vendor constructor is protected, so subclass it.
class _NoFill extends LoadAdError {
  _NoFill() : super(3, 'com.google.android.gms.ads', 'no fill', null);
}

final LoadAdError _failure = _NoFill();

/// A [GoogleAdsPlatform] that records what the adapter asks of the vendor
/// SDK and lets a test play the SDK's callbacks.
class _Platform {
  _Platform({this.size});

  AnchoredAdaptiveBannerAdSize? size;
  final List<(Orientation, int)> lookups = [];
  final List<BannerAd> started = [];
  final List<Ad> released = [];
  Error? startError;
  FutureOr<void> Function(BannerAd ad)? onStart;
  Error? interstitialStartError;
  InterstitialAdLoadCallback? interstitialCallback;

  GoogleAdsPlatform get platform => GoogleAdsPlatform(
    lookupSize: (orientation, width) async {
      lookups.add((orientation, width));
      return size;
    },
    startBanner: (ad) async {
      started.add(ad);
      if (startError != null) throw startError!;
      await onStart?.call(ad);
    },
    startInterstitial: (unitId, callback) async {
      interstitialCallback = callback;
      if (interstitialStartError != null) throw interstitialStartError!;
    },
    releaseAd: (ad) async {
      released.add(ad);
    },
  );
}

void main() {
  /// Runs [body] under fake time and lets its futures finish.
  void timed(void Function(FakeAsync async) body) => fakeAsync(body);

  group('the banner is the adaptive size the SDK picked', () {
    test('the_exact_adaptive_size_object_reaches_the_banner_ad', () {
      timed((async) {
        final vendor = _adaptive(orientation: Orientation.landscape);
        final p = _Platform(size: vendor);
        final sdk = GoogleMobileAdsSdk(platform: p.platform);
        p.onStart = (ad) => ad.listener.onAdLoaded?.call(ad);

        AdBannerSize? size;
        LoadedBanner? banner;
        unawaited(
          sdk.bannerSize(Orientation.landscape, 360).then((v) => size = v),
        );
        async.flushMicrotasks();
        expect(size, const AdBannerSize(width: 360, height: 90));
        expect(p.lookups, [(Orientation.landscape, 360)]);

        unawaited(sdk.loadBanner('unit', size!).then((v) => banner = v));
        async.flushMicrotasks();

        expect(banner, isNotNull);
        final ad = p.started.single;
        // Not a rebuilt AdSize(width:, height:): the vendor's own object,
        // which carries the orientation and "large" to the native side.
        expect(ad.size, same(vendor));
        expect(ad.size, isA<AnchoredAdaptiveBannerAdSize>());
        expect((ad.size as AnchoredAdaptiveBannerAdSize).isLarge, isTrue);
        expect(
          (ad.size as AnchoredAdaptiveBannerAdSize).orientation,
          Orientation.landscape,
        );
        expect(ad.adUnitId, 'unit');
      });
    });

    test('a_size_the_sdk_never_picked_loads_nothing', () {
      timed((async) {
        final p = _Platform(size: _adaptive());
        final sdk = GoogleMobileAdsSdk(platform: p.platform);
        LoadedBanner? banner;
        unawaited(
          sdk
              .loadBanner('unit', const AdBannerSize(width: 1, height: 2))
              .then((v) => banner = v),
        );
        async.flushMicrotasks();
        expect(banner, isNull);
        expect(p.started, isEmpty);
      });
    });

    test('no_size_from_the_sdk_means_no_banner', () {
      timed((async) {
        final sdk = GoogleMobileAdsSdk(platform: _Platform().platform);
        AdBannerSize? size = const AdBannerSize(width: 0, height: 0);
        unawaited(
          sdk.bannerSize(Orientation.portrait, 360).then((v) => size = v),
        );
        async.flushMicrotasks();
        expect(size, isNull);
      });
    });
  });

  group('a banner that fails', () {
    test('a_failed_first_load_releases_the_ad_and_answers_null', () {
      timed((async) {
        final p = _Platform(size: _adaptive());
        final sdk = GoogleMobileAdsSdk(platform: p.platform);
        p.onStart = (ad) => ad.listener.onAdFailedToLoad?.call(ad, _failure);

        LoadedBanner? banner;
        var done = false;
        unawaited(
          sdk.bannerSize(Orientation.portrait, 360).then((size) async {
            banner = await sdk.loadBanner('unit', size!);
            done = true;
          }),
        );
        async.flushMicrotasks();

        expect(done, isTrue);
        expect(banner, isNull);
        expect(p.released, [p.started.single]);
      });
    });

    test('a_failed_refresh_keeps_the_banner_on_screen', () {
      timed((async) {
        final p = _Platform(size: _adaptive());
        final sdk = GoogleMobileAdsSdk(platform: p.platform);
        p.onStart = (ad) => ad.listener.onAdLoaded?.call(ad);

        LoadedBanner? banner;
        unawaited(
          sdk.bannerSize(Orientation.portrait, 360).then((size) async {
            banner = await sdk.loadBanner('unit', size!);
          }),
        );
        async.flushMicrotasks();
        expect(banner, isNotNull);

        // Later, Android reports a refresh with no fill through the same
        // listener. The ad on screen must not be disposed.
        final ad = p.started.single;
        ad.listener.onAdFailedToLoad?.call(ad, _failure);
        async.flushMicrotasks();
        expect(p.released, isEmpty);

        // Disposing it is idempotent: once, however often it is asked.
        banner!
          ..dispose()
          ..dispose();
        async.flushMicrotasks();
        expect(p.released, [ad]);
      });
    });

    test('a_load_that_throws_releases_the_ad', () {
      timed((async) {
        final p = _Platform(size: _adaptive())..startError = StateError('x');
        final sdk = GoogleMobileAdsSdk(platform: p.platform);
        LoadedBanner? banner;
        var done = false;
        unawaited(
          sdk.bannerSize(Orientation.portrait, 360).then((size) async {
            banner = await sdk.loadBanner('unit', size!);
            done = true;
          }),
        );
        async.flushMicrotasks();
        expect(done, isTrue);
        expect(banner, isNull);
        expect(p.released, [p.started.single]);
      });
    });

    test('a_load_that_never_answers_times_out_and_releases_the_ad', () {
      timed((async) {
        final p = _Platform(size: _adaptive());
        final sdk = GoogleMobileAdsSdk(platform: p.platform);
        LoadedBanner? banner;
        var done = false;
        unawaited(
          sdk.bannerSize(Orientation.portrait, 360).then((size) async {
            banner = await sdk.loadBanner('unit', size!);
            done = true;
          }),
        );
        async.flushMicrotasks();
        expect(done, isFalse);

        async.elapse(adLoadTimeout - const Duration(seconds: 1));
        expect(done, isFalse);
        async.elapse(const Duration(seconds: 1));
        expect(done, isTrue);
        expect(banner, isNull);
        expect(p.released, [p.started.single]);

        // A late answer changes nothing and disposes nothing twice.
        final ad = p.started.single;
        ad.listener.onAdLoaded?.call(ad);
        ad.listener.onAdFailedToLoad?.call(ad, _failure);
        async.flushMicrotasks();
        expect(p.released, hasLength(1));
      });
    });
  });

  group('an interstitial', () {
    test('a_load_that_throws_or_fails_answers_null', () {
      timed((async) {
        final thrown = _Platform()..interstitialStartError = StateError('x');
        LoadedInterstitial? ad = _FakeLoaded();
        unawaited(
          GoogleMobileAdsSdk(
            platform: thrown.platform,
          ).loadInterstitial('unit').then((v) => ad = v),
        );
        async.flushMicrotasks();
        expect(ad, isNull);

        final failing = _Platform();
        ad = _FakeLoaded();
        unawaited(
          GoogleMobileAdsSdk(
            platform: failing.platform,
          ).loadInterstitial('unit').then((v) => ad = v),
        );
        async.flushMicrotasks();
        failing.interstitialCallback!.onAdFailedToLoad(_failure);
        async.flushMicrotasks();
        expect(ad, isNull);
      });
    });

    test('a_load_that_never_answers_times_out', () {
      timed((async) {
        final p = _Platform();
        LoadedInterstitial? ad = _FakeLoaded();
        var done = false;
        unawaited(
          GoogleMobileAdsSdk(
            platform: p.platform,
          ).loadInterstitial('unit').then((v) {
            ad = v;
            done = true;
          }),
        );
        async.flushMicrotasks();
        expect(done, isFalse);
        async.elapse(adLoadTimeout);
        expect(done, isTrue);
        expect(ad, isNull);
      });
    });
  });

  group('AdLoadGate', () {
    test('the_first_answer_wins', () {
      timed((async) {
        final gate = AdLoadGate();
        bool? result;
        unawaited(gate.result(adLoadTimeout).then((v) => result = v));
        expect(gate.isPending, isTrue);
        expect(gate.succeed(), isTrue);
        expect(gate.succeed(), isFalse);
        expect(gate.fail(), isFalse);
        async.flushMicrotasks();
        expect(result, isTrue);
        expect(gate.isPending, isFalse);
      });
    });

    test('a_failure_after_success_is_not_a_failure_of_the_load', () {
      final gate = AdLoadGate();
      expect(gate.succeed(), isTrue);
      expect(gate.fail(), isFalse);
    });

    test('silence_is_a_failure_after_the_timeout', () {
      timed((async) {
        final gate = AdLoadGate();
        bool? result;
        unawaited(gate.result(adLoadTimeout).then((v) => result = v));
        async.elapse(adLoadTimeout);
        expect(result, isFalse);
        expect(gate.succeed(), isFalse, reason: 'too late');
      });
    });
  });
}

class _FakeLoaded implements LoadedInterstitial {
  @override
  void dispose() {}

  @override
  Future<bool> show() async => true;
}
