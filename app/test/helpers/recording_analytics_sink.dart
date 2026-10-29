import 'package:tv_remote/core/analytics/app_analytics.dart';

/// An [AnalyticsSink] that remembers what it was given.
///
/// With [throwOnCall] every call throws, to test that callers cope with a
/// failing sink.
class RecordingAnalyticsSink implements AnalyticsSink {
  /// Creates a recording sink.
  RecordingAnalyticsSink({this.throwOnCall = false});

  /// Whether every call throws instead of recording.
  final bool throwOnCall;

  /// Events passed to `logEvent`, in order.
  final List<({String name, Map<String, Object> params})> events = [];

  /// Screen names passed to `logScreenView`, in order.
  final List<String> screens = [];

  /// Events and screens in the order they arrived: `event:<name>` and
  /// `screen:<name>`.
  final List<String> calls = [];

  /// Every value passed to `setCollectionEnabled`, in order.
  final List<bool> collectionHistory = [];

  /// The names of the events received, in order.
  List<String> get eventNames => [for (final e in events) e.name];

  @override
  Future<void> logEvent(String name, Map<String, Object> params) async {
    if (throwOnCall) throw StateError('sink is broken');
    events.add((name: name, params: Map.of(params)));
    calls.add('event:$name');
  }

  @override
  Future<void> logScreenView(String screenName) async {
    if (throwOnCall) throw StateError('sink is broken');
    screens.add(screenName);
    calls.add('screen:$screenName');
  }

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    if (throwOnCall) throw StateError('sink is broken');
    collectionHistory.add(enabled);
  }
}
