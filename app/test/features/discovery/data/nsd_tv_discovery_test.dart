import 'dart:async';
import 'dart:io';

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsd/nsd.dart';
import 'package:tv_remote/features/discovery/data/nsd_tv_discovery.dart';

const _v2 = '_androidtvremote2._tcp';
const _legacy = '_androidtvremote._tcp';

void main() {
  late Map<String, Discovery> discoveries;
  late List<Discovery> stopped;
  late List<(String, bool, IpLookupType)> starts;
  NsdError? legacyStartError;

  Future<Discovery> start(
    String type, {
    bool autoResolve = true,
    IpLookupType ipLookupType = IpLookupType.none,
  }) async {
    starts.add((type, autoResolve, ipLookupType));
    final error = legacyStartError;
    if (error != null && type == _legacy) throw error;
    return discoveries[type] = Discovery(type);
  }

  Future<void> stop(Discovery d) async => stopped.add(d);

  Service svc(
    String name,
    String type, {
    String? ip = '192.168.0.20',
    int? port = 6466,
    String? host = 'tv.local',
  }) => Service(
    name: name,
    type: type,
    port: port,
    host: host,
    addresses: ip == null ? null : [InternetAddress(ip)],
  );

  setUp(() {
    discoveries = {};
    stopped = [];
    starts = [];
    legacyStartError = null;
  });

  NsdTvDiscovery create() => NsdTvDiscovery(start: start, stop: stop);

  test(
    'browses_both_service_types_with_auto_resolve_and_ipv4_lookup',
    () async {
      final d = create()..watch().listen((_) {});
      await pumpEventQueue();
      expect(starts, [
        (_v2, true, IpLookupType.v4),
        (_legacy, true, IpLookupType.v4),
      ]);
      expect(NsdTvDiscovery.serviceTypes, [_v2, _legacy]);
      await d.stop();
    },
  );

  test('emits_resolved_tvs_from_both_service_types', () async {
    final d = create();
    final lists = <List<DiscoveredTv>>[];
    d.watch().listen(lists.add);
    await pumpEventQueue();
    discoveries[_v2]!.add(svc('Living Room TV 3', _v2));
    discoveries[_legacy]!.add(svc('Old Bravia', _legacy, ip: '192.168.0.30'));
    await pumpEventQueue();
    expect(lists.first, isEmpty);
    expect(
      lists.last.map((t) => (t.serviceName, t.host, t.isLegacyService)),
      unorderedEquals([
        ('Living Room TV 3', '192.168.0.20', false),
        ('Old Bravia', '192.168.0.30', true),
      ]),
    );
    await d.stop();
  });

  test('prefers_ipv4_address_over_host_name', () async {
    final d = create();
    final lists = <List<DiscoveredTv>>[];
    d.watch().listen(lists.add);
    await pumpEventQueue();
    discoveries[_v2]!
      ..add(
        Service(
          name: 'Mixed',
          type: _v2,
          port: 6466,
          host: 'tv.local',
          addresses: [InternetAddress('fe80::1'), InternetAddress('10.0.0.7')],
        ),
      )
      ..add(svc('NoAddress', _v2, ip: null));
    await pumpEventQueue();
    expect(
      {for (final t in lists.last) t.serviceName: t.host},
      {
        'Mixed': '10.0.0.7',
        'NoAddress': 'tv.local',
      },
    );
    await d.stop();
  });

  test('skips_unresolved_services', () async {
    final d = create();
    final lists = <List<DiscoveredTv>>[];
    d.watch().listen(lists.add);
    await pumpEventQueue();
    discoveries[_v2]!
      ..add(svc('NoPort', _v2, port: null))
      ..add(svc('NoHost', _v2, ip: null, host: null))
      ..add(const Service(type: _v2, port: 6466, host: 'tv.local'))
      ..add(svc('Resolved', _v2));
    await pumpEventQueue();
    expect(lists.last.map((t) => t.serviceName), ['Resolved']);
    await d.stop();
  });

  test('removes_lost_services', () async {
    final d = create();
    final lists = <List<DiscoveredTv>>[];
    d.watch().listen(lists.add);
    await pumpEventQueue();
    final tv = svc('Living Room TV 3', _v2);
    discoveries[_v2]!.add(tv);
    await pumpEventQueue();
    expect(lists.last, hasLength(1));
    discoveries[_v2]!.remove(tv);
    await pumpEventQueue();
    expect(lists.last, isEmpty);
    await d.stop();
  });

  test('v2_record_wins_over_legacy_with_same_name', () async {
    final d = create();
    final lists = <List<DiscoveredTv>>[];
    d.watch().listen(lists.add);
    await pumpEventQueue();
    discoveries[_legacy]!.add(svc('Same', _legacy, ip: '192.168.0.30'));
    discoveries[_v2]!.add(svc('Same', _v2));
    await pumpEventQueue();
    expect(lists.last, hasLength(1));
    expect(lists.last.single.isLegacyService, isFalse);
    expect(lists.last.single.host, '192.168.0.20');
    await d.stop();
  });

  test(
    'start_failure_surfaces_as_stream_error_and_stops_started_discoveries',
    () async {
      legacyStartError = NsdError(ErrorCause.internalError, 'boom');
      final d = create();
      final errors = <Object>[];
      final done = Completer<void>();
      d.watch().listen((_) {}, onError: errors.add, onDone: done.complete);
      await done.future;
      expect(errors.single, isA<NsdError>());
      expect(stopped, [discoveries[_v2]]);
    },
  );

  test('stop_stops_every_discovery_and_closes_the_stream', () async {
    final d = create();
    final done = Completer<void>();
    d.watch().listen((_) {}, onDone: done.complete);
    await pumpEventQueue();
    await d.stop();
    await d.stop();
    await done.future;
    expect(stopped, unorderedEquals(discoveries.values));
    expect(stopped, hasLength(2));
  });

  test('stop_during_start_stops_late_discoveries', () async {
    final gate = Completer<void>();
    Future<Discovery> slowStart(
      String type, {
      bool autoResolve = true,
      IpLookupType ipLookupType = IpLookupType.none,
    }) async {
      await gate.future;
      return discoveries[type] = Discovery(type);
    }

    final d = NsdTvDiscovery(start: slowStart, stop: stop)
      ..watch().listen((_) {});
    await pumpEventQueue();
    final stopping = d.stop();
    gate.complete();
    await stopping;
    await pumpEventQueue();
    expect(stopped, unorderedEquals(discoveries.values));
    expect(discoveries.keys, [_v2]);
  });

  test('watch_twice_throws', () {
    final d = create()..watch().listen((_) {});
    expect(d.watch, throwsStateError);
  });

  test('stop_completes_when_never_listened', () async {
    // Never watched at all.
    await create().stop().timeout(const Duration(seconds: 1));

    // Watched, but nobody ever listened to the stream.
    final d = create()..watch();
    await pumpEventQueue();
    await d.stop().timeout(const Duration(seconds: 1));
    expect(stopped, unorderedEquals(discoveries.values));
    expect(stopped, hasLength(2));
  });

  test('cancelling_the_stream_stops_discovery', () async {
    var stopCalls = 0;
    Future<void> countingStop(Discovery d) async {
      stopCalls++;
      stopped.add(d);
    }

    final d = NsdTvDiscovery(start: start, stop: countingStop);
    final subscription = d.watch().listen((_) {});
    await pumpEventQueue();
    await subscription.cancel().timeout(const Duration(seconds: 1));
    expect(stopped, unorderedEquals(discoveries.values));
    expect(stopCalls, 2, reason: 'one stopDiscovery per browse');

    // An explicit stop afterwards changes nothing.
    await d.stop().timeout(const Duration(seconds: 1));
    expect(stopCalls, 2);
  });

  test('a_failing_stop_is_not_an_unhandled_error', () async {
    final uncaught = <Object>[];
    var stopCalls = 0;
    await runZonedGuarded(() async {
      final d = NsdTvDiscovery(
        start: start,
        stop: (_) async {
          stopCalls++;
          throw NsdError(ErrorCause.internalError, 'stop failed');
        },
      );
      final subscription = d.watch().listen((_) {});
      await pumpEventQueue();
      // Like DiscoveryController: the cancel isn't awaited.
      unawaited(subscription.cancel());
      await pumpEventQueue();
    }, (error, _) => uncaught.add(error));
    expect(stopCalls, 2, reason: 'both browses were asked to stop');
    expect(uncaught, isEmpty);
  });
}
