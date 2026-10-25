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

    test('throws FormatException for a bad MAC without sending', () {
      expect(
        () => sendWakeOnLan('nope'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
