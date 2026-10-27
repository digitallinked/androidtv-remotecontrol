import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:atv_remote/src/wake_on_lan.dart';
import 'package:test/test.dart';

void main() {
  group('buildMagicPacket', () {
    test('magic_packet_is_102_bytes_with_6xFF_prefix_and_16_mac_repeats', () {
      final packet = buildMagicPacket('AA:BB:CC:DD:EE:FF');

      expect(packet.length, 102);
      expect(packet.sublist(0, 6), List.filled(6, 0xFF));
      const mac = [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF];
      for (var i = 0; i < 16; i++) {
        expect(packet.sublist(6 + i * 6, 12 + i * 6), mac, reason: 'repeat $i');
      }
    });

    test('accepts dashes and lower case', () {
      expect(
        buildMagicPacket('aa-bb-cc-dd-ee-ff'),
        buildMagicPacket('AA:BB:CC:DD:EE:FF'),
      );
    });

    test('rejects_malformed_mac', () {
      for (final bad in [
        '',
        'AA:BB:CC:DD:EE',
        'AA:BB:CC:DD:EE:FF:00',
        'AA:BB:CC:DD:EE:GG',
        'AABBCCDDEEFF',
        'AA:BB-CC:DD:EE:FF',
        'A:BB:CC:DD:EE:FF',
        ' AA:BB:CC:DD:EE:FF',
      ]) {
        expect(
          () => buildMagicPacket(bad),
          throwsFormatException,
          reason: '"$bad"',
        );
      }
    });
  });

  group('sendWakeOnLan', () {
    test('sends the magic packet over UDP to the given address', () async {
      final listener = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(listener.close);
      final received = Completer<Uint8List>();
      listener.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = listener.receive();
          if (datagram != null && !received.isCompleted) {
            received.complete(datagram.data);
          }
        }
      });

      await sendWakeOnLan(
        'AA:BB:CC:DD:EE:FF',
        broadcastAddresses: [InternetAddress.loopbackIPv4],
        port: listener.port,
      );

      final data = await received.future.timeout(const Duration(seconds: 5));
      expect(data, buildMagicPacket('AA:BB:CC:DD:EE:FF'));
      expect(data.length, 102);
    });

    test('still_reaches_a_good_address_after_a_failing_one', () async {
      final listener = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(listener.close);
      final received = Completer<Uint8List>();
      listener.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = listener.receive();
          if (datagram != null && !received.isCompleted) {
            received.complete(datagram.data);
          }
        }
      });

      // An IPv6 address cannot be sent to from the IPv4 socket (send returns
      // 0), so the first send fails.
      await sendWakeOnLan(
        'AA:BB:CC:DD:EE:FF',
        broadcastAddresses: [
          InternetAddress.loopbackIPv6,
          InternetAddress.loopbackIPv4,
        ],
        port: listener.port,
      );

      final data = await received.future.timeout(const Duration(seconds: 5));
      expect(data, buildMagicPacket('AA:BB:CC:DD:EE:FF'));
    });

    test('a bad MAC is never echoed in the error', () {
      try {
        buildMagicPacket('11:22:33:44:55:GG');
        fail('expected a FormatException');
      } on FormatException catch (e) {
        expect(e.source, isNull);
        expect(e.toString(), isNot(contains('GG')));
      }
    });

    test('throws FormatException for a bad MAC without sending', () {
      expect(
        () => sendWakeOnLan('nope'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('sendToEachTarget', () {
    final a = InternetAddress('255.255.255.255');
    final b = InternetAddress('192.168.0.255');
    final c = InternetAddress('10.0.0.255');

    test('tries_every_target_after_one_fails_and_does_not_throw', () {
      final tried = <String>[];
      sendToEachTarget([1, 2, 3], [a, b, c], 9, (buffer, address, port) {
        tried.add(address.address);
        if (address == a) throw const SocketException('unreachable');
        return buffer.length;
      });

      expect(tried, [a.address, b.address, c.address]);
    });

    test('a_zero_byte_send_counts_as_a_failure_for_that_target', () {
      final tried = <String>[];
      sendToEachTarget([1], [a, b], 9, (buffer, address, port) {
        tried.add(address.address);
        return address == a ? 0 : buffer.length;
      });

      expect(tried, [a.address, b.address]);
    });

    test('rethrows_the_first_error_when_every_target_fails', () {
      final errors = [
        const SocketException('first'),
        const SocketException('second'),
      ];
      var call = 0;
      expect(
        () => sendToEachTarget([1], [a, b], 9, (_, _, _) {
          throw errors[call++];
        }),
        throwsA(same(errors.first)),
      );
      expect(call, 2);
    });

    test('all_targets_returning_zero_throws_socket_exception', () {
      expect(
        () => sendToEachTarget([1], [a, b], 9, (_, _, _) => 0),
        throwsA(isA<SocketException>()),
      );
    });

    test('no_targets_sends_nothing_and_does_not_throw', () {
      sendToEachTarget([1], [], 9, (_, _, _) => fail('must not send'));
    });
  });
}
