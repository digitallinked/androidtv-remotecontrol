import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:tv_remote/core/analytics/analytics_sink.dart';

/// The [AnalyticsSink] backed by `FirebaseAnalytics.instance`.
///
/// This is the only file that imports `firebase_analytics`. Every call
/// catches everything, `MissingPluginException` included: analytics must never
/// become a crash.
class FirebaseAnalyticsSink implements AnalyticsSink {
  /// Creates the sink. It touches Firebase only when a method is called.
  const FirebaseAnalyticsSink();

  @override
  Future<void> logEvent(String name, Map<String, Object> params) async {
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: name,
        parameters: params.isEmpty ? null : params,
      );
    } on Object {
      // Nothing more can be done about a failing Analytics.
    }
  }

  @override
  Future<void> logScreenView(String screenName) async {
    try {
      await FirebaseAnalytics.instance.logScreenView(screenName: screenName);
    } on Object {
      // Nothing more can be done about a failing Analytics.
    }
  }

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    try {
      final analytics = FirebaseAnalytics.instance;
      await analytics.setAnalyticsCollectionEnabled(enabled);
      // Consent mode: only analytics storage follows the user's choice;
      // nothing is ever granted for ads.
      await analytics.setConsent(
        analyticsStorageConsentGranted: enabled,
        adStorageConsentGranted: false,
        adUserDataConsentGranted: false,
        adPersonalizationSignalsConsentGranted: false,
      );
    } on Object {
      // Collection stays off natively until it can be turned on.
    }
  }
}
