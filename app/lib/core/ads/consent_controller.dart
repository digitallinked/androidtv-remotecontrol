import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/ads/consent_service.dart';
import 'package:tv_remote/core/privacy/privacy_choices.dart';
import 'package:tv_remote/core/purchases/premium.dart';

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
    this.formShown = false,
  });

  /// Before anything is known: ads may not load.
  const ConsentResult.notGathered(this.region)
    : canRequestAds = false,
      privacyOptionsRequired = false,
      gathered = false,
      formShown = false;

  /// The region consent was resolved for.
  final ConsentRegion region;

  /// Whether ads may be requested. Always `false` until [gathered].
  final bool canRequestAds;

  /// Whether the user must be able to reopen their consent choices.
  final bool privacyOptionsRequired;

  /// Whether the consent form step has finished (shown, not needed, or
  /// failed). Ads wait for it.
  final bool gathered;

  /// Whether the consent form was shown to the user on this launch. The
  /// review prompt never follows it in the same launch (Ruling P6-C11).
  final bool formShown;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConsentResult &&
          other.region == region &&
          other.canRequestAds == canRequestAds &&
          other.privacyOptionsRequired == privacyOptionsRequired &&
          other.gathered == gathered &&
          other.formShown == formShown;

  @override
  int get hashCode => Object.hash(
    region,
    canRequestAds,
    privacyOptionsRequired,
    gathered,
    formShown,
  );

  @override
  String toString() =>
      'ConsentResult(region: $region, canRequestAds: $canRequestAds, '
      'privacyOptionsRequired: $privacyOptionsRequired, gathered: $gathered, '
      'formShown: $formShown)';
}

/// Runs the ad consent steps once per launch (Ruling P6-R3 and P6-R8).
///
/// 1. [refresh], right after the first frame: a silent update that writes
///    the consent region. It shows nothing.
/// 2. [ensureGathered], the first time the remote is the top route: the
///    consent form, if the platform requires one and the user doesn't have
///    Premium (Ruling P7-R9).
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
      formShown: state.formShown,
    );
  }

  /// Shows the consent form if the platform requires one, once per launch,
  /// and publishes the result. A Premium user is never shown the form; the
  /// result then says `formShown: false`. Concurrent and later calls share
  /// the first one's outcome.
  Future<ConsentResult> ensureGathered() => _gathered ??= _gatherOnce();

  Future<ConsentResult> _gatherOnce() async {
    // Read before the first await: after the container is disposed the ref
    // can't be used, and the caller (a screen) doesn't await this.
    final service = _service;
    await refresh();
    if (!ref.mounted) return _disposed;
    // A Premium user is shown no ads, so asking for ad consent is noise: the
    // form is skipped, the cached entitlement included (Ruling P7-R9). The
    // silent update above still ran, so "Ad privacy choices" shows whenever
    // the platform requires it. A wrong cache costs at most this launch's
    // ads: the next launch caches "free" and shows the form.
    final ConsentFormOutcome outcome;
    if (_isPremium()) {
      outcome = ConsentFormOutcome.notNeeded;
    } else {
      // A failed form is not an error here: the platform may still allow ads
      // from an earlier choice, and `canRequestAds` says.
      outcome = await _guard(
        service.showFormIfRequired,
        ConsentFormOutcome.failed,
      );
      if (!ref.mounted) return _disposed;
    }
    final canRequest = await _guard(service.canRequestAds, false);
    if (!ref.mounted) return _disposed;
    final options = await _guard(service.privacyOptionsRequired, false);
    if (!ref.mounted) return _disposed;
    final result = ConsentResult(
      region: ref.read(consentRegionStateProvider),
      canRequestAds: canRequest,
      privacyOptionsRequired: options,
      gathered: true,
      formShown: outcome == ConsentFormOutcome.shown,
    );
    state = result;
    return result;
  }

  /// Whether the user has Premium, cached or confirmed. A Premium state that
  /// can't be read counts as free, so the form still shows.
  bool _isPremium() {
    try {
      return ref.read(premiumProvider).isPremium;
    } on Object catch (error) {
      developer.log('premium unreadable', name: 'consent', error: error);
      return false;
    }
  }

  /// What a gather that outlived its container answers: nothing is known and
  /// nothing is published.
  static const _disposed = ConsentResult.notGathered(ConsentRegion.unknown);

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
        formShown: state.formShown,
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
