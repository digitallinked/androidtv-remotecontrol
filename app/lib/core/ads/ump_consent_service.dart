import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:tv_remote/app/flavor.dart';
import 'package:tv_remote/core/ads/consent_service.dart';
import 'package:tv_remote/core/config/service_config.dart';
import 'package:tv_remote/core/privacy/privacy_choices.dart';

/// [ConsentService] backed by Google's UMP in `google_mobile_ads`.
///
/// This is one of the two files that import `google_mobile_ads`, and it uses
/// UMP only: it never starts the ads SDK. Every call catches everything,
/// `MissingPluginException` included: a failing consent platform leaves the
/// answers `unknown`, `failed` and `false`, which keep ads off, and never
/// becomes a crash.
class UmpConsentService implements ConsentService {
  /// Creates the service. It touches the platform only when a method is
  /// called.
  ///
  /// In [Flavor.dev], `UMP_DEBUG_GEOGRAPHY` (`eea` or `other`) and
  /// `UMP_TEST_DEVICE_ID` in [config] make the platform act as in that
  /// region on that device. [Flavor.prod] ignores both.
  UmpConsentService(this.config, this.flavor);

  /// The build's values.
  final ServiceConfig config;

  /// The running flavor.
  final Flavor flavor;

  /// How long the silent update may take before it counts as unknown.
  static const _updateTimeout = Duration(seconds: 15);

  /// The region UMP's [status] implies (Ruling P6-R4). The ad consent
  /// choices never count as consent for the app's own analytics, so
  /// `obtained` still means "the region needs consent".
  @visibleForTesting
  static ConsentRegion regionOf(ConsentStatus status) => switch (status) {
    ConsentStatus.notRequired => ConsentRegion.notRequired,
    ConsentStatus.required || ConsentStatus.obtained => ConsentRegion.required,
    ConsentStatus.unknown => ConsentRegion.unknown,
  };

  /// The parameters of the silent update.
  @visibleForTesting
  ConsentRequestParameters buildParameters() {
    final geography = switch (config.umpDebugGeography) {
      'eea' => DebugGeography.debugGeographyEea,
      'other' => DebugGeography.debugGeographyOther,
      _ => null,
    };
    if (flavor != Flavor.dev || geography == null) {
      return ConsentRequestParameters();
    }
    final deviceId = config.umpTestDeviceId;
    return ConsentRequestParameters(
      consentDebugSettings: ConsentDebugSettings(
        debugGeography: geography,
        testIdentifiers: deviceId == null ? null : [deviceId],
      ),
    );
  }

  @override
  Future<ConsentRegion> requestUpdate() async {
    try {
      if (!await _requestInfoUpdate()) return ConsentRegion.unknown;
      return regionOf(await ConsentInformation.instance.getConsentStatus());
    } on Object catch (error) {
      _log('consent update failed', error);
      return ConsentRegion.unknown;
    }
  }

  /// Runs the callback-style update as a future; `false` when it failed.
  ///
  /// The plugin starts it as an unawaited async call and reports only
  /// platform errors to the failure listener, so a missing plugin escapes as
  /// an uncaught error of the zone. The guarded zone catches that too.
  Future<bool> _requestInfoUpdate() {
    final done = Completer<bool>();
    void finish({required bool ok}) {
      if (!done.isCompleted) done.complete(ok);
    }

    runZonedGuarded(
      () => ConsentInformation.instance.requestConsentInfoUpdate(
        buildParameters(),
        () => finish(ok: true),
        (error) {
          _log('consent update refused', error.message);
          finish(ok: false);
        },
      ),
      (error, _) {
        _log('consent update failed', error);
        finish(ok: false);
      },
    );
    return done.future.timeout(_updateTimeout, onTimeout: () => false);
  }

  @override
  Future<ConsentFormOutcome> showFormIfRequired() async {
    try {
      // The platform doesn't say whether it showed anything, so ask first.
      final status = await ConsentInformation.instance.getConsentStatus();
      FormError? error;
      await ConsentForm.loadAndShowConsentFormIfRequired((e) => error = e);
      if (error != null) {
        _log('consent form failed', error?.message);
        return ConsentFormOutcome.failed;
      }
      return status == ConsentStatus.required
          ? ConsentFormOutcome.shown
          : ConsentFormOutcome.notNeeded;
    } on Object catch (error) {
      _log('consent form failed', error);
      return ConsentFormOutcome.failed;
    }
  }

  @override
  Future<bool> canRequestAds() async {
    try {
      return await ConsentInformation.instance.canRequestAds();
    } on Object catch (error) {
      _log('canRequestAds failed', error);
      return false;
    }
  }

  @override
  Future<bool> privacyOptionsRequired() async {
    try {
      return await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } on Object catch (error) {
      _log('privacy options status failed', error);
      return false;
    }
  }

  @override
  Future<bool> showPrivacyOptions() async {
    try {
      FormError? error;
      await ConsentForm.showPrivacyOptionsForm((e) => error = e);
      if (error != null) {
        _log('privacy options form failed', error?.message);
        return false;
      }
      return true;
    } on Object catch (error) {
      _log('privacy options form failed', error);
      return false;
    }
  }

  void _log(String what, Object? error) =>
      developer.log(what, name: 'consent', error: error);
}
