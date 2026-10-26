import 'package:atv_remote/atv_remote.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsd/nsd.dart';
import 'package:tv_remote/features/discovery/application/discovery_controller.dart';
import 'package:tv_remote/features/discovery/data/discovery_providers.dart';

import '../../helpers/fake_tv_discovery.dart';

DiscoveredTv _named(String serviceName, String displayName) => DiscoveredTv(
  serviceName: serviceName,
  displayName: displayName,
  host: '192.168.0.20',
  port: 6466,
  isLegacyService: false,
);

void main() {
  late FakeTvDiscoveries discoveries;

  ProviderContainer makeContainer() {
    final container = ProviderContainer.test(
      overrides: [
        tvDiscoveryFactoryProvider.overrideWithValue(discoveries.create),
      ],
    )..listen(discoveryControllerProvider, (_, _) {}); // autoDispose
    return container;
  }

  DiscoveryState read(ProviderContainer c) =>
      c.read(discoveryControllerProvider);

  setUp(() => discoveries = FakeTvDiscoveries());

  test('state_compares_by_value', () {
    expect(
      DiscoveryState(
        tvs: [tv('a')],
        showTroubleshooting: false,
        failed: false,
      ),
      DiscoveryState(
        tvs: [tv('a')],
        showTroubleshooting: false,
        failed: false,
      ),
    );
    expect(
      DiscoveryState(
        tvs: [tv('a')],
        showTroubleshooting: false,
        failed: false,
      ),
      isNot(
        DiscoveryState(
          tvs: [tv('b')],
          showTroubleshooting: false,
          failed: false,
        ),
      ),
    );
  });

  test('sorts_tvs_by_display_name_case_insensitively', () {
    fakeAsync((async) {
      final c = makeContainer();
      discoveries.created.single.emit([tv('b'), tv('A'), tv('c')]);
      async.flushMicrotasks();
      expect(read(c).tvs.map((t) => t.displayName), ['A', 'b', 'c']);
    });
  });

  test('equal_names_are_ordered_by_service_name', () {
    fakeAsync((async) {
      final c = makeContainer();
      discoveries.created.single.emit([
        _named('z', 'Den'),
        _named('a', 'Den'),
      ]);
      async.flushMicrotasks();
      expect(read(c).tvs.map((t) => t.serviceName), ['a', 'z']);
    });
  });

  test('troubleshooting_after_10s_without_tvs', () {
    fakeAsync((async) {
      final c = makeContainer();
      async.elapse(const Duration(milliseconds: 9900));
      expect(read(c).showTroubleshooting, isFalse);
      async.elapse(const Duration(milliseconds: 100));
      expect(read(c).showTroubleshooting, isTrue);
      expect(read(c).failed, isFalse);
    });
  });

  test('no_troubleshooting_once_a_tv_is_found', () {
    fakeAsync((async) {
      final c = makeContainer();
      discoveries.created.single.emit([tv('a')]);
      async.elapse(discoveryEmptyTimeout * 2);
      expect(read(c).tvs, hasLength(1));
      expect(read(c).showTroubleshooting, isFalse);
    });
  });

  test('troubleshooting_returns_if_every_tv_disappears_after_10s', () {
    fakeAsync((async) {
      final c = makeContainer();
      discoveries.created.single.emit([tv('a')]);
      async.elapse(discoveryEmptyTimeout);
      discoveries.created.single.emit(const []);
      async.flushMicrotasks();
      expect(read(c).showTroubleshooting, isTrue);
    });
  });

  test('start_failure_sets_failed_and_troubleshooting', () {
    fakeAsync((async) {
      final c = makeContainer();
      discoveries.created.single.fail(
        NsdError(ErrorCause.securityIssue, 'denied'),
      );
      async.flushMicrotasks();
      expect(read(c).failed, isTrue);
      expect(read(c).showTroubleshooting, isTrue);
    });
  });

  test('rescan_restarts_discovery_and_the_timer', () {
    fakeAsync((async) {
      final c = makeContainer();
      async.elapse(discoveryEmptyTimeout);
      expect(read(c).showTroubleshooting, isTrue);

      c.read(discoveryControllerProvider.notifier).rescan();
      async.elapse(Duration.zero);

      expect(discoveries.created, hasLength(2));
      expect(discoveries.created.first.stopped, isTrue);
      expect(discoveries.created.last.stopped, isFalse);
      expect(read(c).showTroubleshooting, isFalse);
      async.elapse(const Duration(milliseconds: 9900));
      expect(read(c).showTroubleshooting, isFalse);
      async.elapse(const Duration(milliseconds: 100));
      expect(read(c).showTroubleshooting, isTrue);
    });
  });

  test('rescan_clears_a_failure', () {
    fakeAsync((async) {
      final c = makeContainer();
      discoveries.created.single.fail(StateError('x'));
      async.flushMicrotasks();
      expect(read(c).failed, isTrue);

      c.read(discoveryControllerProvider.notifier).rescan();
      async.elapse(Duration.zero);
      expect(read(c).failed, isFalse);
      expect(read(c).tvs, isEmpty);
    });
  });

  test('dispose_stops_discovery', () {
    fakeAsync((async) {
      final c = makeContainer();
      final first = discoveries.created.single;
      expect(first.stopped, isFalse);
      c.dispose();
      async.flushMicrotasks();
      expect(first.stopped, isTrue);
      // The timer was cancelled: nothing is left to fire.
      expect(async.pendingTimers, isEmpty);
    });
  });
}
