import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
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
  Future<void> setCollectionEnabled(bool enabled) => applyAnalyticsSwitch(
    enabled: enabled,
    // Consent mode: only analytics storage follows the user's choice;
    // nothing is ever granted for ads.
    setStorage: (granted) => FirebaseAnalytics.instance.setConsent(
      analyticsStorageConsentGranted: granted,
      adStorageConsentGranted: false,
      adUserDataConsentGranted: false,
      adPersonalizationSignalsConsentGranted: false,
    ),
    setCollection: (on) =>
        FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(on),
  );
}

/// Turns analytics on or off with [setStorage] (the analytics-storage
/// consent) and [setCollection] (native collection), in a safe order.
///
/// - **On:** storage is granted first; if that fails, collection stays off.
///   Then collection starts.
/// - **Off:** collection stops first, then storage is denied. Both always
///   run, so a failing consent call never leaves collection on.
///
/// It never throws.
@visibleForTesting
Future<void> applyAnalyticsSwitch({
  required bool enabled,
  // The shape of the Firebase calls they wrap: one positional boolean.
  // ignore: avoid_positional_boolean_parameters
  required Future<void> Function(bool) setStorage,
  // The same shape as above.
  // ignore: avoid_positional_boolean_parameters
  required Future<void> Function(bool) setCollection,
}) async {
  if (enabled) {
    try {
      await setStorage(true);
    } on Object {
      // Collection stays off natively until it can be turned on.
      return;
    }
    try {
      await setCollection(true);
    } on Object {
      // Nothing more can be done about a failing Analytics.
    }
  } else {
    try {
      await setCollection(false);
    } on Object {
      // Storage is still denied below.
    }
    try {
      await setStorage(false);
    } on Object {
      // Nothing more can be done about a failing Analytics.
    }
  }
}
