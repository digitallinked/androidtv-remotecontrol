import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tv_remote/core/ads/ads_service.dart';

/// An [AdsSdk] that touches no platform, counts what it is asked and, when
/// told to, "loads" ads.
///
/// By default it starts but never loads: banners and interstitials come back
/// as `null`, so every screen sees the zero-size slot of Phase 5. Pass
/// `loads: true` for ads that load at once (the banner is a [ColoredBox]
/// with the key `fake_banner`).
class FakeAdsSdk implements AdsSdk {
  /// Creates a fake.
  FakeAdsSdk({
    this.loads = false,
    this.failLoads = false,
    this.failInitialize = false,
    this.bannerHeight = 60,
    this.holdInterstitialLoad,
  });

  /// Whether loads succeed.
  bool loads;

  /// Whether every load (banner and interstitial) fails with `null`, even
  /// when [loads] is true.
  bool failLoads;

  /// Whether [initialize] throws.
  bool failInitialize;

  /// The height of the banners [bannerSize] answers with.
  int bannerHeight;

  /// When set, [loadInterstitial] waits for it.
  Completer<void>? holdInterstitialLoad;

  /// How many times [initialize] was called.
  int initializeCalls = 0;

  /// How many times [bannerSize] was called.
  int bannerSizeCalls = 0;

  /// How many times [loadBanner] was called.
  int bannerLoads = 0;

  /// The unit ids [loadBanner] was called with, in order.
  final List<String> bannerUnits = [];

  /// How many banners were disposed.
  int disposed = 0;

  /// How many times [loadInterstitial] was called.
  int interstitialLoads = 0;

  /// The unit ids [loadInterstitial] was called with, in order.
  final List<String> interstitialUnits = [];

  /// How many interstitials were shown.
  int shows = 0;

  /// How many interstitials were disposed.
  int interstitialsDisposed = 0;

  @override
  Future<void> initialize() async {
    initializeCalls++;
    if (failInitialize) throw StateError('ads sdk');
  }

  @override
  Future<AdBannerSize?> bannerSize(Orientation orientation, int width) async {
    bannerSizeCalls++;
    return AdBannerSize(width: width, height: bannerHeight);
  }

  @override
  Future<LoadedBanner?> loadBanner(String unitId, AdBannerSize size) async {
    bannerLoads++;
    bannerUnits.add(unitId);
    if (!loads || failLoads) return null;
    return _Banner(this, size);
  }

  @override
  Future<LoadedInterstitial?> loadInterstitial(String unitId) async {
    interstitialLoads++;
    interstitialUnits.add(unitId);
    await holdInterstitialLoad?.future;
    if (!loads || failLoads) return null;
    return _Interstitial(this);
  }
}

class _Banner implements LoadedBanner {
  _Banner(this._sdk, this._size);

  final FakeAdsSdk _sdk;
  final AdBannerSize _size;

  @override
  Widget get widget => ColoredBox(
    key: const ValueKey('fake_banner'),
    color: Colors.amber,
    child: SizedBox(
      width: _size.width.toDouble(),
      height: _size.height.toDouble(),
    ),
  );

  @override
  void dispose() => _sdk.disposed++;
}

class _Interstitial implements LoadedInterstitial {
  _Interstitial(this._sdk);

  final FakeAdsSdk _sdk;

  @override
  Future<void> show() async => _sdk.shows++;

  @override
  void dispose() => _sdk.interstitialsDisposed++;
}
