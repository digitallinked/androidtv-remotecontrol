import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/tv/mac_address.dart';

void main() {
  test('parse_mac_accepts_common_formats_and_normalises', () {
    for (final raw in [
      'aa:bb:cc:dd:ee:f0',
      'AA-BB-CC-DD-EE-F0',
      'aabb.ccdd.eef0',
      ' AABBCCDDEEF0 ',
    ]) {
      expect(parseMac(raw), 'AA:BB:CC:DD:EE:F0', reason: raw);
    }
  });

  test('parse_mac_rejects_invalid_multicast_and_reserved', () {
    for (final raw in [
      '',
      'AA:BB:CC:DD:EE',
      'GG:BB:CC:DD:EE:FF',
      '00:00:00:00:00:00',
      'FF:FF:FF:FF:FF:FF',
      '01:00:5E:00:00:01',
      'AA:BB:CC:DD:EE:FF:00',
    ]) {
      expect(parseMac(raw), isNull, reason: raw);
    }
  });

  test('parse_mac_rejects_mixed_separators_and_misplaced_dots', () {
    for (final raw in [
      'AA:BB-CC:DD-EE:F0',
      'AA.BB.CC.DD.EE.F0',
      'AABB:CCDD:EEF0',
      'aabbccdd.eef0',
    ]) {
      expect(parseMac(raw), isNull, reason: raw);
    }
  });
}
