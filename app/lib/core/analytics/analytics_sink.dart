/// Where analytics events are handed to the analytics service.
///
/// `firebase_analytics_sink.dart` is the only code that imports
/// `firebase_analytics`; everything else talks to this interface, so tests use
/// a recording fake. A sink gets only events that passed the guard and the
/// user's choice (`AppAnalytics`).
abstract interface class AnalyticsSink {
  /// Sends the event [name] with [params] (strings and integers).
  Future<void> logEvent(String name, Map<String, Object> params);

  /// Sends a screen view for the route [screenName].
  Future<void> logScreenView(String screenName);

  /// Turns native collection on or off. While it is off nothing is sent.
  // The brief fixes this positional signature.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setCollectionEnabled(bool enabled);
}

/// A sink that does nothing: used when Firebase is not running.
class NoopAnalyticsSink implements AnalyticsSink {
  /// Creates the sink.
  const NoopAnalyticsSink();

  @override
  Future<void> logEvent(String name, Map<String, Object> params) async {}

  @override
  Future<void> logScreenView(String screenName) async {}

  @override
  Future<void> setCollectionEnabled(bool enabled) async {}
}
