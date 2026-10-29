import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/analytics/firebase_analytics_sink.dart';

void main() {
  late List<String> calls;

  // The sink's own callback shape: one positional boolean.
  // ignore: avoid_positional_boolean_parameters
  Future<void> Function(bool) record(String name, {bool fails = false}) =>
      (value) async {
        calls.add('$name:$value');
        if (fails) throw StateError('$name failed');
      };

  setUp(() => calls = []);

  test('switching_on_grants_storage_before_collection', () async {
    await applyAnalyticsSwitch(
      enabled: true,
      setStorage: record('storage'),
      setCollection: record('collection'),
    );
    expect(calls, ['storage:true', 'collection:true']);
  });

  test('switching_off_stops_collection_before_storage', () async {
    await applyAnalyticsSwitch(
      enabled: false,
      setStorage: record('storage'),
      setCollection: record('collection'),
    );
    expect(calls, ['collection:false', 'storage:false']);
  });

  test('a_failing_storage_call_still_turns_collection_off', () async {
    await applyAnalyticsSwitch(
      enabled: false,
      setStorage: record('storage', fails: true),
      setCollection: record('collection'),
    );
    expect(calls, contains('collection:false'));
  });

  test('a_failing_collection_call_still_denies_storage', () async {
    await applyAnalyticsSwitch(
      enabled: false,
      setStorage: record('storage'),
      setCollection: record('collection', fails: true),
    );
    expect(calls, ['collection:false', 'storage:false']);
  });

  test('a_failing_storage_call_never_turns_collection_on', () async {
    await applyAnalyticsSwitch(
      enabled: true,
      setStorage: record('storage', fails: true),
      setCollection: record('collection'),
    );
    expect(calls, ['storage:true']);
  });

  test('the_switch_never_throws', () async {
    for (final enabled in [true, false]) {
      await expectLater(
        applyAnalyticsSwitch(
          enabled: enabled,
          setStorage: record('storage', fails: true),
          setCollection: record('collection', fails: true),
        ),
        completes,
      );
    }
  });
}
