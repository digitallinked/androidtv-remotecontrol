import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:tv_remote/core/ads/ads_service.dart';
import 'package:tv_remote/core/ads/consent_service.dart';
import 'package:tv_remote/core/ads/tracking_service.dart';

import 'fake_ads_sdk.dart';
import 'fake_consent_service.dart';
import 'fake_tracking_service.dart';

/// The ad consent, tracking and ads SDK services as fakes, for tests that
/// build the whole app (`buildRootWidget`) and so never reach a platform
/// channel.
///
/// Pass [consent] or [sdk] to keep hold of a fake and read its counters.
List<Override> fakeAdsOverrides({
  FakeConsentService? consent,
  FakeAdsSdk? sdk,
}) => [
  consentServiceProvider.overrideWithValue(consent ?? FakeConsentService()),
  trackingServiceProvider.overrideWithValue(FakeTrackingService()),
  adsSdkProvider.overrideWithValue(sdk ?? FakeAdsSdk()),
];
