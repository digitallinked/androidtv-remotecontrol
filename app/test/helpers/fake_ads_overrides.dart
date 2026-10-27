import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:tv_remote/core/ads/consent_service.dart';
import 'package:tv_remote/core/ads/tracking_service.dart';

import 'fake_consent_service.dart';
import 'fake_tracking_service.dart';

/// The ad consent and tracking services as fakes, for tests that build the
/// whole app (`buildRootWidget`) and so never reach a platform channel.
///
/// Pass [consent] to keep hold of the consent fake and read its counters.
List<Override> fakeAdsOverrides({FakeConsentService? consent}) => [
  consentServiceProvider.overrideWithValue(consent ?? FakeConsentService()),
  trackingServiceProvider.overrideWithValue(FakeTrackingService()),
];
