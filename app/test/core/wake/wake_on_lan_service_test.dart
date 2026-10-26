import 'dart:async';
import 'dart:io';

import 'package:atv_remote/atv_remote.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/wake/wake_on_lan_service.dart';

const _mac = 'AA:BB:CC:DD:EE:FF';

List<String> _addresses(List<InternetAddress>? targets) =>
    targets!.map((a) => a.address).toList();

void main() {
  group('wakeOnLanTargets', () {
    test(
      'targets_include_limited_and_subnet_broadcast',
      () => expect(
        wakeOnLanTargets(
          subnetBroadcast: '192.168.0.255',
          tvHost: '10.0.0.7',
        ).map((a) => a.address),
        ['255.255.255.255', '192.168.0.255', '10.0.0.255'],
      ),
    );

    test(
      'falls_back_to_slash_24_of_tv_host_when_subnet_unknown',
      () => expect(
        wakeOnLanTargets(tvHost: '192.168.0.20').map((a) => a.address),
        ['255.255.255.255', '192.168.0.255'],
      ),
    );

    test('deduplicates_and_ignores_non_ipv4_values', () {
      expect(
        wakeOnLanTargets(
          subnetBroadcast: '192.168.0.255',
          tvHost: '192.168.0.20',
        ).map((a) => a.address),
        ['255.255.255.255', '192.168.0.255'],
      );
      expect(
        wakeOnLanTargets(
          subnetBroadcast: 'garbage',
          tvHost: 'tv.local',
        ).map((a) => a.address),
        ['255.255.255.255'],
      );
    });
  });

  group('WakeOnLanService', () {
    late String? sentMac;
    late List<List<String>> sentCalls;
    late int sendCount;

    setUp(() {
      sentMac = null;
      sentCalls = [];
      sendCount = 0;
    });

    Future<void> recordingSender(
      String mac, {
      List<InternetAddress>? broadcastAddresses,
      int port = 9,
    }) async {
      sendCount++;
      sentMac = mac;
      sentCalls.add(_addresses(broadcastAddresses));
    }

    test('wake_sends_to_every_target', () async {
      final service = WakeOnLanService(
        subnetBroadcast: () async => '192.168.0.255',
        send: recordingSender,
      );

      final sent = await service.wake(mac: _mac, tvHost: '10.0.0.7');

      expect(sent, isTrue);
      expect(sentMac, _mac);
      expect(sentCalls, [
        ['255.255.255.255'],
        ['192.168.0.255', '10.0.0.255'],
      ]);
    });

    test('lookup_failure_or_timeout_still_sends_limited_broadcast', () {
      fakeAsync((async) {
        final throwing = WakeOnLanService(
          subnetBroadcast: () async => throw StateError('no wifi'),
          send: recordingSender,
        );
        bool? sentAfterThrow;
        unawaited(
          throwing
              .wake(mac: _mac, tvHost: '192.168.5.9')
              .then((v) => sentAfterThrow = v),
        );
        async.flushMicrotasks();
        expect(sentAfterThrow, isTrue);
        expect(sentCalls, [
          ['255.255.255.255'],
          ['192.168.5.255'],
        ]);

        sentCalls.clear();
        final hanging = WakeOnLanService(
          subnetBroadcast: () => Completer<String?>().future,
          send: recordingSender,
        );
        bool? sentAfterTimeout;
        unawaited(
          hanging
              .wake(mac: _mac, tvHost: '192.168.5.9')
              .then((v) => sentAfterTimeout = v),
        );
        async.elapse(const Duration(seconds: 1));
        expect(sentAfterTimeout, isNull);
        expect(sentCalls, [
          ['255.255.255.255'],
        ]);
        async.elapse(const Duration(seconds: 1));
        expect(sentAfterTimeout, isTrue);
        expect(sentCalls, [
          ['255.255.255.255'],
          ['192.168.5.255'],
        ]);
      });
    });

    test('limited_broadcast_is_sent_before_the_lookup_finishes', () {
      fakeAsync((a) {
        final calls = <List<String>>[];
        final service = WakeOnLanService(
          subnetBroadcast: () => Completer<String?>().future,
          send: (mac, {broadcastAddresses, port = 9}) async =>
              calls.add(_addresses(broadcastAddresses)),
        );
        unawaited(service.wake(mac: _mac, tvHost: '192.168.0.20'));
        a.flushMicrotasks();
        expect(calls, [
          ['255.255.255.255'],
        ]);
        a.elapse(const Duration(seconds: 2));
        expect(calls, [
          ['255.255.255.255'],
          ['192.168.0.255'],
        ]);
      });
    });

    test('sync_throwing_lookup_still_sends_the_tv_fallback', () async {
      final calls = <List<String>>[];
      final service = WakeOnLanService(
        subnetBroadcast: () => throw StateError('x'),
        send: (mac, {broadcastAddresses, port = 9}) async =>
            calls.add(_addresses(broadcastAddresses)),
      );

      expect(await service.wake(mac: _mac, tvHost: '192.168.0.20'), isTrue);
      expect(calls, [
        ['255.255.255.255'],
        ['192.168.0.255'],
      ]);
    });

    test('os_error_lookup_still_sends_the_tv_fallback', () async {
      final calls = <List<String>>[];
      final service = WakeOnLanService(
        subnetBroadcast: () async => throw const OSError('denied'),
        send: (mac, {broadcastAddresses, port = 9}) async =>
            calls.add(_addresses(broadcastAddresses)),
      );

      expect(await service.wake(mac: _mac, tvHost: '192.168.0.20'), isTrue);
      expect(calls, [
        ['255.255.255.255'],
        ['192.168.0.255'],
      ]);
    });

    test('returns_true_when_any_send_succeeds', () async {
      var n = 0;
      final service = WakeOnLanService(
        subnetBroadcast: () async => '192.168.0.255',
        send: (mac, {broadcastAddresses, port = 9}) async {
          if (n++ == 0) throw const SocketException('unreachable');
        },
      );

      expect(await service.wake(mac: _mac), isTrue);
      expect(n, 2);
    });

    test('returns_false_when_every_send_fails', () async {
      var n = 0;
      final service = WakeOnLanService(
        subnetBroadcast: () async => '192.168.0.255',
        send: (mac, {broadcastAddresses, port = 9}) async {
          n++;
          throw n.isOdd
              ? const SocketException('unreachable')
              : const OSError('denied');
        },
      );

      expect(await service.wake(mac: _mac), isFalse);
      expect(n, 2);
    });

    test('no_second_send_when_nothing_else_to_try', () async {
      final calls = <List<String>>[];
      final service = WakeOnLanService(
        subnetBroadcast: () async => null,
        send: (mac, {broadcastAddresses, port = 9}) async =>
            calls.add(_addresses(broadcastAddresses)),
      );

      expect(await service.wake(mac: _mac), isTrue);
      expect(calls, [
        ['255.255.255.255'],
      ]);
    });

    test('provider_builds_a_service', () {
      final container = ProviderContainer.test();
      expect(
        container.read(wakeOnLanServiceProvider),
        isA<WakeOnLanService>(),
      );
    });

    test(
      'real_sender_still_reaches_later_targets_when_the_first_fails',
      () async {
        final listener = await RawDatagramSocket.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        addTearDown(listener.close);
        final received = Completer<List<int>>();
        listener.listen((event) {
          final datagram = event == RawSocketEvent.read
              ? listener.receive()
              : null;
          if (datagram != null && !received.isCompleted) {
            received.complete(datagram.data);
          }
        });
        // The real sender, aimed at the loopback listener. The first target
        // is an IPv6 address the IPv4 socket can't send to, so it fails; the
        // second must still be tried and wake() must report success.
        final service = WakeOnLanService(
          subnetBroadcast: () async => null,
          send: (mac, {broadcastAddresses, port = 9}) => sendWakeOnLan(
            mac,
            broadcastAddresses: [
              InternetAddress.loopbackIPv6,
              InternetAddress.loopbackIPv4,
            ],
            port: listener.port,
          ),
        );

        expect(await service.wake(mac: _mac), isTrue);
        expect(
          await received.future.timeout(const Duration(seconds: 5)),
          buildMagicPacket(_mac),
        );
      },
    );

    test('send_failure_returns_false', () async {
      final service = WakeOnLanService(
        subnetBroadcast: () async => null,
        send: (mac, {broadcastAddresses, port = 9}) async =>
            throw const SocketException('network unreachable'),
      );

      expect(await service.wake(mac: _mac), isFalse);
    });

    test('malformed_mac_throws_format_exception_without_sending', () async {
      var looked = false;
      final service = WakeOnLanService(
        subnetBroadcast: () async {
          looked = true;
          return null;
        },
        send: recordingSender,
      );

      await expectLater(
        service.wake(mac: 'not-a-mac'),
        throwsA(isA<FormatException>()),
      );
      expect(sendCount, 0);
      expect(looked, isFalse);
    });
  });
}
