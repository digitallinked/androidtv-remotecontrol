import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/app/flavor.dart';
import 'package:tv_remote/core/analytics/analytics_strings.dart';
import 'package:tv_remote/core/config/firebase_remote_config_source.dart';
import 'package:tv_remote/core/firebase/firebase_bootstrap.dart';

part 'app_config.g.dart';

/// The Remote Config values the app reads, each with its in-code default
/// (Ruling P6-R7).
///
/// A value of the wrong type, a number outside its sane range or a blank
/// string falls back to the default of that key alone. The interstitial
/// interval must be 60 s to 7 days, the review threshold 1 to 10000 key
/// presses, and the paywall variant a plain token (letters, digits, `_`, `.`,
/// at most 100 characters; surrounding spaces are trimmed).
@immutable
class AppConfigValues {
  const AppConfigValues._({
    required this.adsBannerEnabled,
    required this.adsInterstitialEnabled,
    required this.adsInterstitialMinInterval,
    required this.reviewPromptMinKeyPresses,
    required this.paywallVariant,
    required this.minSupportedVersion,
    required this.catalogueVersion,
  });

  /// Reads every key through [get], which returns the raw value of a key
  /// (or `null` for a key that has none). [get] may throw: that key then
  /// keeps its default.
  factory AppConfigValues.read(Object? Function(String key) get) {
    Object? raw(String key) {
      try {
        return get(key);
      } on Object {
        return null;
      }
    }

    bool boolean(String key, {required bool fallback}) {
      final value = raw(key);
      return value is bool ? value : fallback;
    }

    int count(String key, int fallback, {int min = 0, int? max}) {
      final value = raw(key);
      return value is int && value >= min && (max == null || value <= max)
          ? value
          : fallback;
    }

    String text(String key, String fallback) {
      final value = raw(key);
      return value is String && value.trim().isNotEmpty ? value : fallback;
    }

    // Goes into analytics as a parameter, so it must pass the guard's
    // string rules.
    String token(String key, String fallback) {
      final value = raw(key);
      final trimmed = value is String ? value.trim() : '';
      return analyticsStringViolations(trimmed).isEmpty ? trimmed : fallback;
    }

    return AppConfigValues._(
      adsBannerEnabled: boolean(_adsBanner, fallback: true),
      adsInterstitialEnabled: boolean(_adsInterstitial, fallback: false),
      adsInterstitialMinInterval: Duration(
        seconds: count(
          _interstitialInterval,
          600,
          min: 60,
          max: Duration.secondsPerDay * 7,
        ),
      ),
      reviewPromptMinKeyPresses: count(
        _reviewKeyPresses,
        150,
        min: 1,
        max: 10000,
      ),
      paywallVariant: token(_paywallVariant, 'a'),
      minSupportedVersion: text(_minSupportedVersion, '1.0.0'),
      catalogueVersion: count(_catalogueVersion, 1),
    );
  }

  static const _adsBanner = 'ads_banner_enabled';
  static const _adsInterstitial = 'ads_interstitial_enabled';
  static const _interstitialInterval = 'ads_interstitial_min_interval_s';
  static const _reviewKeyPresses = 'review_prompt_min_key_presses';
  static const _paywallVariant = 'paywall_variant';
  static const _minSupportedVersion = 'min_supported_version';
  static const _catalogueVersion = 'catalogue_version';

  /// What the app uses until, or unless, a configuration is activated.
  static const AppConfigValues defaults = AppConfigValues._(
    adsBannerEnabled: true,
    adsInterstitialEnabled: false,
    adsInterstitialMinInterval: Duration(seconds: 600),
    reviewPromptMinKeyPresses: 150,
    paywallVariant: 'a',
    minSupportedVersion: '1.0.0',
    catalogueVersion: 1,
  );

  /// [defaults] by Remote Config key. The key names and value types here are
  /// what the console must publish; the type of each default decides how a
  /// fetched text is read.
  static const Map<String, Object> defaultsMap = {
    _adsBanner: true,
    _adsInterstitial: false,
    _interstitialInterval: 600,
    _reviewKeyPresses: 150,
    _paywallVariant: 'a',
    _minSupportedVersion: '1.0.0',
    _catalogueVersion: 1,
  };

  /// `ads_banner_enabled`: the banner kill switch.
  final bool adsBannerEnabled;

  /// `ads_interstitial_enabled`: interstitials are off unless this is on.
  final bool adsInterstitialEnabled;

  /// `ads_interstitial_min_interval_s`: the least time between interstitials.
  final Duration adsInterstitialMinInterval;

  /// `review_prompt_min_key_presses`: key presses before the review prompt.
  final int reviewPromptMinKeyPresses;

  /// `paywall_variant`: which paywall variant to show.
  final String paywallVariant;

  /// `min_supported_version`: older app versions get the update screen.
  final String minSupportedVersion;

  /// `catalogue_version`: the app catalogue version the config asks for.
  final int catalogueVersion;

  @override
  bool operator ==(Object other) =>
      other is AppConfigValues &&
      other.adsBannerEnabled == adsBannerEnabled &&
      other.adsInterstitialEnabled == adsInterstitialEnabled &&
      other.adsInterstitialMinInterval == adsInterstitialMinInterval &&
      other.reviewPromptMinKeyPresses == reviewPromptMinKeyPresses &&
      other.paywallVariant == paywallVariant &&
      other.minSupportedVersion == minSupportedVersion &&
      other.catalogueVersion == catalogueVersion;

  @override
  int get hashCode => Object.hash(
    adsBannerEnabled,
    adsInterstitialEnabled,
    adsInterstitialMinInterval,
    reviewPromptMinKeyPresses,
    paywallVariant,
    minSupportedVersion,
    catalogueVersion,
  );
}

/// Where the configuration comes from.
///
/// Values fetched in one launch apply from the next launch (Ruling P6-R7):
/// [activateCached] makes last launch's fetch current, [fetchForNextLaunch]
/// downloads for the launch after this one.
abstract interface class RemoteConfigSource {
  /// Makes the values fetched on an earlier launch the current ones.
  Future<void> activateCached();

  /// Downloads the latest values. They become current on the next launch.
  Future<void> fetchForNextLaunch();

  /// The current value of [key]: a `bool`, an `int` or a `String`, or `null`
  /// when there is none or it can't be read as the type of the key's default.
  Object? value(String key);
}

/// A [RemoteConfigSource] with nothing in it, so every key keeps its default.
/// Used when Firebase isn't running.
class DefaultsOnlyConfigSource implements RemoteConfigSource {
  /// Creates the empty source.
  const DefaultsOnlyConfigSource();

  @override
  Future<void> activateCached() async {}

  @override
  Future<void> fetchForNextLaunch() async {}

  @override
  Object? value(String key) => null;
}

/// The configuration source: Firebase Remote Config when Firebase is ready
/// (fetch interval 1 h for prod, 5 min for dev), else defaults only.
@Riverpod(keepAlive: true)
RemoteConfigSource remoteConfigSource(Ref ref) {
  if (ref.watch(firebaseStatusProvider) != FirebaseStatus.ready) {
    return const DefaultsOnlyConfigSource();
  }
  final prod = ref.watch(flavorProvider) == Flavor.prod;
  return FirebaseRemoteConfigSource(
    minimumFetchInterval: prod
        ? const Duration(hours: 1)
        : const Duration(minutes: 5),
  );
}

/// The Remote Config values for this session.
///
/// The state is [AppConfigValues.defaults] until [load] has activated the
/// values fetched on an earlier launch, and it never changes after that, so
/// nothing flips mid-session.
@Riverpod(keepAlive: true)
class AppConfig extends _$AppConfig {
  bool _started = false;
  bool _sealed = false;

  @override
  AppConfigValues build() => AppConfigValues.defaults;

  /// Ends the window in which [load] may set the state. Startup calls it
  /// once the config step has finished or been given up on, so a [load] that
  /// is still waiting on a slow platform never changes the values mid-session
  /// (Ruling P6-R7). The download for the next launch still starts then.
  void seal() => _sealed = true;

  /// Activates the cached values, sets the state from them and starts a
  /// download for the next launch without waiting for it.
  ///
  /// Runs once: a second call, or a call after [seal], does nothing. Never
  /// throws: a failing source keeps the defaults. Startup bounds the time this
  /// may take; if the bound passes first, the state stays as it is.
  Future<void> load() async {
    if (_started || _sealed) return;
    _started = true;
    final source = ref.read(remoteConfigSourceProvider);
    try {
      await source.activateCached();
      if (!ref.mounted) return;
      if (!_sealed) state = AppConfigValues.read(source.value);
    } on Object catch (error) {
      developer.log('Remote Config failed', name: 'config', error: error);
    }
    if (!ref.mounted) return;
    unawaited(
      Future.sync(source.fetchForNextLaunch).then<void>(
        (_) {},
        onError: (Object error) => developer.log(
          'Remote Config fetch failed',
          name: 'config',
          error: error,
        ),
      ),
    );
  }
}
