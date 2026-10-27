import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/ads/consent_service.dart';
import 'package:tv_remote/core/privacy/privacy_choices.dart';

part 'consent_controller.g.dart';

/// What the app knows about ad consent.
@immutable
class ConsentResult {
  /// Creates a result.
  const ConsentResult({
    required this.region,
    required this.canRequestAds,
    required this.privacyOptionsRequired,
    required this.gathered,
  });

  /// Before anything is known: ads may not load.
  const ConsentResult.notGathered(this.region)
    : canRequestAds = false,
      privacyOptionsRequired = false,
      gathered = false;

  /// The region consent was resolved for.
  final ConsentRegion region;

  /// Whether ads may be requested. Always `false` until [gathered].
  final bool canRequestAds;

  /// Whether the user must be able to reopen their consent choices.
  final bool privacyOptionsRequired;

  /// Whether the consent form step has finished (shown, not needed, or
  /// failed). Ads wait for it.
  final bool gathered;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConsentResult &&
          other.region == region &&
          other.canRequestAds == canRequestAds &&
          other.privacyOptionsRequired == privacyOptionsRequired &&
          other.gathered == gathered;

  @override
  int get hashCode =>
      Object.hash(region, canRequestAds, privacyOptionsRequired, gathered);

  @override
  String toString() =>
      'ConsentResult(region: $region, canRequestAds: $canRequestAds, '
      'privacyOptionsRequired: $privacyOptionsRequired, gathered: $gathered)';
}

/// Runs the ad consent steps once per launch (Ruling P6-R3 and P6-R8).
///
/// 1. [refresh], right after the first frame: a silent update that writes
///    the consent region. It shows nothing.
/// 2. [ensureGathered], the first time the remote is the top route: the
///    consent form, if the platform requires one.
///
/// No method throws; a failing platform leaves ads off.
@Riverpod(keepAlive: true)
class ConsentController extends _$ConsentController {
  Future<void>? _refresh;
  Future<ConsentResult>? _gathered;

  @override
  ConsentResult build() {
    ref.watch(consentServiceProvider);
    // The first read starts the silent update. A microtask, so the state
    // exists before the update tries to change it.
    scheduleMicrotask(() {
      if (ref.mounted) unawaited(refresh());
    });
    return ConsentResult.notGathered(ref.read(consentRegionStateProvider));
  }

  ConsentService get _service => ref.read(consentServiceProvider);

  /// The silent consent update, once per launch: stores the region the
  /// platform reports, unless it can't say (`unknown` keeps what is stored),
  /// and learns whether the privacy-options entry is needed.
  Future<void> refresh() => _refresh ??= _refreshOnce();

  Future<void> _refreshOnce() async {
    final service = _service;
    final region = await _guard(service.requestUpdate, ConsentRegion.unknown);
    if (!ref.mounted) return;
    if (region != ConsentRegion.unknown) {
      await _guard(
        () => ref.read(consentRegionStateProvider.notifier).set(region),
        null,
      );
      if (!ref.mounted) return;
    }
    final options = await _guard(service.privacyOptionsRequired, false);
    if (!ref.mounted) return;
    state = ConsentResult(
      region: ref.read(consentRegionStateProvider),
      canRequestAds: state.canRequestAds,
      privacyOptionsRequired: options,
      gathered: state.gathered,
    );
  }

  /// Shows the consent form if the platform requires one, once per launch,
  /// and publishes the result. Concurrent and later calls share the first
  /// one's outcome.
  Future<ConsentResult> ensureGathered() => _gathered ??= _gatherOnce();

  Future<ConsentResult> _gatherOnce() async {
    await refresh();
    final service = _service;
    // A failed form is not an error here: the platform may still allow ads
    // from an earlier choice, and `canRequestAds` says.
    await _guard(service.showFormIfRequired, ConsentFormOutcome.failed);
    final canRequest = await _guard(service.canRequestAds, false);
    final options = await _guard(service.privacyOptionsRequired, false);
    final result = ConsentResult(
      region: ref.mounted
          ? ref.read(consentRegionStateProvider)
          : ConsentRegion.unknown,
      canRequestAds: canRequest,
      privacyOptionsRequired: options,
      gathered: true,
    );
    if (ref.mounted) state = result;
    return result;
  }

  /// Opens the privacy-options form (the "Ad privacy choices" row). Returns
  /// `false` when it could not be shown. Afterwards the choice may have
  /// changed whether ads can load, so that is read again.
  Future<bool> showPrivacyOptions() async {
    final service = _service;
    final shown = await _guard(service.showPrivacyOptions, false);
    final canRequest = await _guard(service.canRequestAds, false);
    if (ref.mounted) {
      state = ConsentResult(
        region: state.region,
        canRequestAds: canRequest && state.gathered,
        privacyOptionsRequired: state.privacyOptionsRequired,
        gathered: state.gathered,
      );
    }
    return shown;
  }

  /// Runs [call]; an error gives [fallback], so nothing here throws.
  Future<T> _guard<T>(Future<T> Function() call, T fallback) async {
    try {
      return await call();
    } on Object catch (error) {
      developer.log('consent step failed', name: 'consent', error: error);
      return fallback;
    }
  }
}
