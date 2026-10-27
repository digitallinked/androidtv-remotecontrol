import 'dart:async';
import 'dart:developer' as developer;

import 'package:atv_remote/atv_remote.dart';
import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/ads/ads_service.dart';
import 'package:tv_remote/core/ads/consent_controller.dart';
import 'package:tv_remote/core/ads/tracking_service.dart';
import 'package:tv_remote/core/config/app_config.dart';
import 'package:tv_remote/core/purchases/premium.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/remote/application/remote_actions.dart';

part 'interstitials.g.dart';

/// Where an interstitial may be shown (Ruling P6-R9). There is one place.
enum InterstitialTrigger {
  /// The user left the Settings hub.
  leftSettings,
}

/// How long after a connection loss or a "Not connected" notice no
/// interstitial shows.
const Duration interstitialQuietAfterTrouble = Duration(seconds: 60);

/// The launch on which interstitials start; the first launch has none.
const int interstitialFirstLaunch = 2;

/// Interstitial pacing (Ruling P6-R9). They are off unless Remote Config
/// turns them on.
///
/// One ad is kept loaded in advance, so [maybeShow] never waits for a load:
/// an ad that isn't ready is simply not shown. Nothing here throws.
///
/// The app keeps this provider listened to (`App` watches it): Riverpod
/// pauses a provider nothing listens to, and the listeners below with it.
@Riverpod(keepAlive: true)
class Interstitials extends _$Interstitials {
  LoadedInterstitial? _loaded;
  Future<void>? _loading;
  DateTime? _lastTroubleAt;
  bool _wasConnected = false;

  @override
  void build() {
    ref
      ..onDispose(_drop)
      ..listen(connectionStateProvider, (_, next) {
        final status = next.value?.status;
        if (next.isLoading || status == null) return;
        if (status == ConnectionStatus.connected) {
          _wasConnected = true;
        } else if (_wasConnected) {
          // Any way out of "connected" counts, the app's own disconnects
          // included: the cost of a missed ad is nothing.
          _wasConnected = false;
          _lastTroubleAt = clock.now();
        }
      })
      ..listen(notConnectedNoticesProvider, (_, _) {
        _lastTroubleAt = clock.now();
      })
      // Premium and consent arrive after start; each may allow the preload.
      // Premium arriving drops the ad that is waiting.
      ..listen(premiumProvider, (_, next) {
        if (next.isPremium) {
          _drop();
        } else {
          unawaited(_preload());
        }
      })
      ..listen(consentControllerProvider, (_, _) => unawaited(_preload()));
    scheduleMicrotask(() {
      if (ref.mounted) unawaited(_preload());
    });
  }

  /// Releases the loaded ad, if any.
  void _drop() {
    _loaded?.dispose();
    _loaded = null;
  }

  /// Whether an interstitial may load now: the same rules as showing one,
  /// except the ones about time and trouble.
  ///
  /// It does not start the consent form: the preload waits until the form
  /// step has finished.
  Future<bool> _mayLoad() async {
    if (!ref.read(appConfigProvider).adsInterstitialEnabled) return false;
    if (ref.read(adUnitIdsProvider).interstitial == null) return false;
    final premium = ref.read(premiumProvider);
    if (!premium.known || premium.isPremium) return false;
    final store = ref.read(settingsStoreProvider);
    if (store.launchCount < interstitialFirstLaunch) return false;
    final consent = ref.read(consentControllerProvider);
    if (!consent.gathered || !consent.canRequestAds) return false;
    // Before the system question has been answered, no ad request may go out
    // (Ruling P6-R8): the banner makes the decision first.
    final tracking = ref.read(trackingServiceProvider);
    return await tracking.status() != TrackingStatus.notDetermined;
  }

  /// Loads the next ad if none is loaded or loading. Never throws.
  Future<void> _preload() {
    if (_loaded != null) return Future.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<void> _load() async {
    try {
      if (!await _mayLoad() || !ref.mounted) return;
      final unitId = ref.read(adUnitIdsProvider).interstitial;
      final sdk = ref.read(adsSdkProvider);
      if (unitId == null) return;
      if (!await ref.read(adsControllerProvider.notifier).ready()) return;
      if (!ref.mounted) return;
      final ad = await sdk.loadInterstitial(unitId);
      if (ad == null) return;
      // Premium may have arrived, or the container gone, while it loaded.
      if (!ref.mounted ||
          _loaded != null ||
          ref.read(premiumProvider).isPremium) {
        ad.dispose();
        return;
      }
      _loaded = ad;
    } on Object catch (error) {
      developer.log('interstitial preload failed', name: 'ads', error: error);
    }
  }

  /// Shows the loaded interstitial for [trigger] if every rule holds, and
  /// returns whether it did. It never waits for a load: with no ad ready it
  /// returns `false` at once and starts loading the next one.
  ///
  /// The rules: Remote Config has them on; the user is known not to have
  /// Premium and is not in the demo; ads may be requested; this is at least
  /// the second launch; the minimum interval since the last one has passed
  /// (it survives restarts); and no connection loss or "Not connected"
  /// notice happened in the last 60 s.
  Future<bool> maybeShow(InterstitialTrigger trigger) async {
    try {
      final config = ref.read(appConfigProvider);
      final premium = ref.read(premiumProvider);
      final store = ref.read(settingsStoreProvider);
      final now = clock.now();
      final last = store.interstitialLastShownAt;
      final trouble = _lastTroubleAt;
      final isDemo = ref.read(remoteSessionProvider).value?.isDemo ?? false;
      final ad = _loaded;

      if (!config.adsInterstitialEnabled) return false;
      if (!premium.known || premium.isPremium || isDemo) return false;
      if (!ref.read(consentControllerProvider).canRequestAds) return false;
      if (store.launchCount < interstitialFirstLaunch) return false;
      if (last != null &&
          now.difference(last) < config.adsInterstitialMinInterval) {
        return false;
      }
      if (trouble != null &&
          now.difference(trouble) < interstitialQuietAfterTrouble) {
        return false;
      }
      if (ad == null) {
        unawaited(_preload());
        return false;
      }

      _loaded = null;
      await store.setInterstitialLastShownAt(now);
      await ad.show();
      ad.dispose();
      if (ref.mounted) unawaited(_preload());
      return true;
    } on Object catch (error) {
      developer.log('interstitial failed', name: 'ads', error: error);
      return false;
    }
  }
}
