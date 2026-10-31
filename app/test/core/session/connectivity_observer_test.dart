import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/session/connectivity_observer.dart';

void main() {
  late StreamController<List<ConnectivityResult>> source;
  late ConnectivityObserver observer;
  late List<void> events;
  late List<Object> errors;

  setUp(() {
    source = StreamController<List<ConnectivityResult>>();
    observer = ConnectivityObserver(source.stream);
    events = [];
    errors = [];
    observer.changes.listen(events.add, onError: errors.add);
  });
  tearDown(() async {
    observer.dispose();
    await source.close();
  });

  test('first_event_is_a_baseline', () async {
    source.add([ConnectivityResult.wifi]);
    await pumpEventQueue();
    expect(events, isEmpty);
  });

  test('emits_on_change_to_a_connected_network', () async {
    source
      ..add([ConnectivityResult.wifi])
      ..add([ConnectivityResult.mobile]);
    await pumpEventQueue();
    expect(events, hasLength(1));
  });

  test('ignores_none_and_duplicates', () async {
    source
      ..add([ConnectivityResult.wifi])
      ..add([ConnectivityResult.none])
      ..add([ConnectivityResult.wifi])
      ..add([ConnectivityResult.wifi]);
    await pumpEventQueue();
    expect(events, hasLength(1));
  });

  test('result_order_does_not_matter', () async {
    source
      ..add([ConnectivityResult.wifi, ConnectivityResult.vpn])
      ..add([ConnectivityResult.vpn, ConnectivityResult.wifi]);
    await pumpEventQueue();
    expect(events, isEmpty);
  });

  test('source_errors_are_swallowed', () async {
    source
      ..add([ConnectivityResult.wifi])
      ..addError(StateError('boom'));
    await pumpEventQueue();
    expect(errors, isEmpty);
    source.add([ConnectivityResult.mobile]);
    await pumpEventQueue();
    expect(errors, isEmpty);
    expect(events, hasLength(1));
  });

  test('resync_replaces_the_baseline_so_a_return_to_it_is_a_change', () async {
    source.add([ConnectivityResult.wifi]);
    await pumpEventQueue();
    observer.resync([ConnectivityResult.mobile]);
    source.add([ConnectivityResult.wifi]);
    await pumpEventQueue();
    expect(events, hasLength(1));
  });

  test('resync_to_the_same_value_emits_nothing', () async {
    source.add([ConnectivityResult.wifi]);
    await pumpEventQueue();
    observer.resync([ConnectivityResult.wifi]);
    await pumpEventQueue();
    expect(events, isEmpty);
    source.add([ConnectivityResult.wifi]);
    await pumpEventQueue();
    expect(events, isEmpty);
  });

  test('nothing_is_emitted_after_dispose', () async {
    source.add([ConnectivityResult.wifi]);
    await pumpEventQueue();
    observer.dispose();
    source.add([ConnectivityResult.mobile]);
    await pumpEventQueue();
    expect(events, isEmpty);
  });

  // The platform-backed subscriptions (this one, PlatformSessionSignals'
  // foreground stream, Premium's entitlements) cancel unawaited on dispose:
  // a platform whose cancel fails must not leave an unhandled error.
  test('a_source_whose_cancel_fails_disposes_cleanly', () async {
    final uncaught = <Object>[];
    var cancelled = false;
    await runZonedGuarded(() async {
      final failing = StreamController<List<ConnectivityResult>>(
        onCancel: () {
          cancelled = true;
          throw StateError('the platform channel is gone');
        },
      );
      final o = ConnectivityObserver(failing.stream);
      var closed = false;
      o.changes.listen((_) {}, onDone: () => closed = true);
      await pumpEventQueue();
      o.dispose();
      await pumpEventQueue();
      expect(closed, isTrue, reason: 'changes still closes');
    }, (error, _) => uncaught.add(error));
    expect(cancelled, isTrue);
    expect(uncaught, isEmpty);
  });
}
