import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/tv/host_resolver.dart';

import '../../helpers/fake_tv_discovery.dart';

void main() {
  test('returns_host_of_matching_service', () async {
    final f = FakeTvDiscoveries();
    final result = resolveHostByServiceName(f.create, 'Living Room TV 3');
    await pumpEventQueue();
    f.created.single.emit([
      tv('Other'),
      tv('Living Room TV 3', host: '192.168.0.99'),
    ]);
    expect(await result, '192.168.0.99');
    expect(f.created.single.stopped, isTrue);
  });

  test('ignores_legacy_records_with_the_same_name', () async {
    final f = FakeTvDiscoveries();
    final result = resolveHostByServiceName(f.create, 'Living Room TV 3');
    await pumpEventQueue();
    f.created.single
      ..emit([tv('Living Room TV 3', host: '192.168.0.50', legacy: true)])
      ..emit([tv('Living Room TV 3', host: '192.168.0.99')]);
    expect(await result, '192.168.0.99');
  });

  test('returns_null_after_timeout_and_stops_discovery', () {
    fakeAsync((async) {
      final f = FakeTvDiscoveries();
      String? result = 'unset';
      unawaited(
        resolveHostByServiceName(
          f.create,
          'Living Room TV 3',
        ).then((h) => result = h),
      );
      async.elapse(const Duration(seconds: 3));
      expect(result, 'unset');
      async.elapse(const Duration(seconds: 2));
      expect(result, isNull);
      expect(f.created.single.stopped, isTrue);
    });
  });

  test('stream_error_returns_null_and_stops', () async {
    final f = FakeTvDiscoveries();
    final result = resolveHostByServiceName(f.create, 'Living Room TV 3');
    await pumpEventQueue();
    f.created.single.fail(StateError('mdns down'));
    expect(await result, isNull);
    expect(f.created.single.stopped, isTrue);
  });
}
