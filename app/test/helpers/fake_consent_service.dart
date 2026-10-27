import 'dart:async';

import 'package:tv_remote/core/ads/consent_service.dart';
import 'package:tv_remote/core/privacy/privacy_choices.dart';

/// A [ConsentService] that answers from its fields, counts the calls it gets
/// and can be held open.
///
/// The defaults are a user outside the regions that need consent: no form,
/// ads allowed, no privacy-options entry.
class FakeConsentService implements ConsentService {
  /// Creates a fake; every field can also be changed afterwards.
  FakeConsentService({
    this.region = ConsentRegion.notRequired,
    this.canRequest = true,
    this.optionsRequired = false,
    this.formOutcome = ConsentFormOutcome.notNeeded,
    this.optionsResult = true,
    this.holdRequestUpdate,
    this.holdShowForm,
    this.holdShowPrivacyOptions,
  });

  /// What [requestUpdate] answers.
  ConsentRegion region;

  /// What [canRequestAds] answers.
  bool canRequest;

  /// What [privacyOptionsRequired] answers.
  bool optionsRequired;

  /// What [showFormIfRequired] answers.
  ConsentFormOutcome formOutcome;

  /// What [showPrivacyOptions] answers.
  bool optionsResult;

  /// When set, [requestUpdate] waits for it.
  Completer<void>? holdRequestUpdate;

  /// When set, [showFormIfRequired] waits for it.
  Completer<void>? holdShowForm;

  /// When set, [showPrivacyOptions] waits for it.
  Completer<void>? holdShowPrivacyOptions;

  /// How many times [requestUpdate] was called.
  int requestUpdateCalls = 0;

  /// How many times [showFormIfRequired] was called.
  int showFormCalls = 0;

  /// How many times [showPrivacyOptions] was called.
  int privacyOptionsCalls = 0;

  @override
  Future<ConsentRegion> requestUpdate() async {
    requestUpdateCalls++;
    await holdRequestUpdate?.future;
    return region;
  }

  @override
  Future<ConsentFormOutcome> showFormIfRequired() async {
    showFormCalls++;
    await holdShowForm?.future;
    return formOutcome;
  }

  @override
  Future<bool> canRequestAds() async => canRequest;

  @override
  Future<bool> privacyOptionsRequired() async => optionsRequired;

  @override
  Future<bool> showPrivacyOptions() async {
    privacyOptionsCalls++;
    await holdShowPrivacyOptions?.future;
    return optionsResult;
  }
}
