import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/crash/crash_scrubber.dart';

const _pem = '''
-----BEGIN CERTIFICATE-----
MIIBszCCAVmgAwIBAgIUQw0rPVo3JkZ1bW9yZXRoYW5hbGlhc2VzdHVm
-----END CERTIFICATE-----''';

void main() {
  test('scrubs_ipv4_and_ipv6', () {
    final s = CrashScrubber();
    expect(
      s.scrub(
        'SocketException: Connection refused (OS Error: Connection refused, '
        'errno = 111), address = 192.168.0.20, port = 6466',
      ),
      allOf(
        contains('<ip>'),
        isNot(contains('192.168.0.20')),
        contains('port = 6466'),
      ),
    );
    expect(
      s.scrub('fe80::1c2b:3a4d:5e6f:7a8b%wlan0 unreachable'),
      isNot(contains('fe80')),
    );
  });

  group('ip_forms', () {
    final s = CrashScrubber();
    const cases = <String, String>{
      '10.0.0.1': '<ip>',
      'at 192.168.1.255:6466 failed': 'at <ip>:6466 failed',
      '::1 refused': '<ip> refused',
      '[fe80::1]:6466': '[<ip>]:6466',
      '2001:db8:85a3:0:0:8a2e:370:7334 down': '<ip> down',
      '2001:db8::ff00:42:8329': '<ip>',
      '::ffff:192.168.0.20': '<ip>:<ip>',
      'ip:fe80::abcd': 'ip:<ip>',
    };
    for (final entry in cases.entries) {
      test(entry.key, () => expect(s.scrub(entry.key), entry.value));
    }

    test('does_not_touch_version_numbers_or_line_numbers', () {
      expect(s.scrub('Android 12.0.1 build 999.1.1.256'), contains('12.0.1'));
      expect(
        s.scrub('package:tv_remote/core/x.dart:123:45'),
        'package:tv_remote/core/x.dart:123:45',
      );
    });
  });

  test('scrubs_mac_in_every_format', () {
    final s = CrashScrubber();
    for (final mac in const [
      'AA:BB:CC:DD:EE:F0',
      'aa-bb-cc-dd-ee-f0',
      'aabb.ccdd.eef0',
      'AABBCCDDEEF0',
      '00:1a:2b:3c:4d:5e',
    ]) {
      final out = s.scrub('Wake-on-LAN to $mac failed');
      expect(out, anyOf('Wake-on-LAN to <mac> failed', contains('<hex>')));
      expect(out.toLowerCase(), isNot(contains(mac.toLowerCase())));
    }
    expect(s.scrub('mac AA:BB:CC:DD:EE:F0'), 'mac <mac>');
    expect(s.scrub('mac aa-bb-cc-dd-ee-f0'), 'mac <mac>');
    expect(s.scrub('mac aabb.ccdd.eef0'), 'mac <mac>');
    expect(s.scrub('mac AABBCCDDEEF0'), 'mac <mac>');
  });

  test('scrubs_pairing_codes_hex_pins_and_keys', () {
    final s = CrashScrubber();
    expect(s.scrub('code A1B2C3 rejected'), 'code <code> rejected');
    expect(s.scrub('code a1b2c3'), 'code <code>');
    expect(s.scrub('code 123456'), 'code <code>');
    final pin = '0123456789abcdef' * 4;
    expect(s.scrub('pin $pin changed'), 'pin <hex> changed');
    final pem = s.scrub('bad cert\n$_pem\nend');
    expect(pem, 'bad cert\n<pem>\nend');
    expect(pem, isNot(contains('MIIB')));
    const key =
        'MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEq8Z3vN1w5Rk2aJ7m4Bt9Xc6LpYh0Uo';
    expect(key.length, greaterThanOrEqualTo(60));
    expect(s.scrub('key $key was rejected'), 'key <b64> was rejected');
  });

  test('scrubs_a_truncated_pem_block', () {
    final out = CrashScrubber().scrub(
      'x -----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASC',
    );
    expect(out, 'x <pem>');
  });

  test('scrubs_saved_tv_names_service_names_and_hosts', () {
    final s = CrashScrubber(
      knownTerms: () => const [
        'Living Room TV 3',
        'Den',
        'manual:192.168.0.20',
      ],
    );
    final out = s.scrub(
      'No route to Living Room TV 3._androidtvremote2._tcp.local; '
      'bravia-4k.local; Den is offline; hidden and garden; '
      'manual:192.168.0.20 failed; living   room tv 3 again',
    );
    expect(out, isNot(contains('Living')));
    expect(out, isNot(contains('living')));
    expect(out, isNot(contains('bravia')));
    expect(out, isNot(contains('Den')));
    expect(out, isNot(contains('192.168')));
    expect(out, contains('hidden'));
    expect(out, contains('garden'));
    expect(out, contains('<host>'));
    expect(out, contains('<tv> is offline'));
  });

  test('scrubs_manual_entries_even_when_not_listed', () {
    expect(
      CrashScrubber().scrub('no pin for manual:192.168.0.20 or manual:fe80::1'),
      'no pin for <tv> or <tv>',
    );
  });

  test('known_terms_are_read_on_every_call_and_short_ones_ignored', () {
    var terms = <String>['Den'];
    final s = CrashScrubber(knownTerms: () => terms);
    expect(s.scrub('Den up'), '<tv> up');
    terms = ['Bedroom', 'TV', '  ', ''];
    expect(s.scrub('Den up in Bedroom with TV'), 'Den up in <tv> with TV');
  });

  test('known_terms_with_regex_characters_are_matched_literally', () {
    final s = CrashScrubber(knownTerms: () => const ['TV (2nd) [old]+']);
    expect(s.scrub('on TV (2nd) [old]+ now'), 'on <tv> now');
    expect(s.scrub('on TV 2nd old now'), 'on TV 2nd old now');
  });

  test('scrubs_unsaved_mdns_service_names_and_local_hosts', () {
    final s = CrashScrubber();
    expect(
      s.scrub('found Bedroom TV._androidtvremote2._tcp.local.'),
      isNot(contains('Bedroom')),
    );
    expect(s.scrub('lookup BRAVIA-4K.local failed'), 'lookup <host> failed');
    expect(s.scrub('x._androidtvremote._tcp y'), isNot(contains('_tcp')));
  });

  test('scrubs_links_that_can_carry_user_text_or_package_names', () {
    final s = CrashScrubber();
    expect(
      s.scrub(
        'Could not launch mailto:help@example.com?subject=Hi&body=my%20tv',
      ),
      'Could not launch <uri>',
    );
    expect(
      s.scrub('market://launch?id=com.secret.app failed'),
      '<uri> failed',
    );
    expect(s.scrub('write to someone@example.org now'), 'write to <email> now');
  });

  group('names_with_quotes_and_brackets_do_not_leak', () {
    const leaks = ['Mike', 'Sony', 'Bedroom'];
    final saved = CrashScrubber(
      knownTerms: () => const ["Mike's TV", 'Sony (Bedroom)'],
    );
    final unsaved = CrashScrubber();

    final cases = <String, List<CrashScrubber>>{
      "No route to Mike's TV._androidtvremote2._tcp.local.": [saved, unsaved],
      'found Sony (Bedroom)._androidtvremote2._tcp.local.': [saved, unsaved],
      "found 'Mike's TV'._androidtvremote2._tcp": [saved, unsaved],
      "/pair/Mike's%20TV._androidtvremote2._tcp.local": [saved, unsaved],
      "/pair/Mike's%20TV": [saved],
      '/devices/Sony%20(Bedroom)': [saved],
      "[<'Mike's TV'>]": [saved],
      "key [<'Sony (Bedroom)'>] lost": [saved],
      "Mike's TV, Sony (Bedroom)": [saved],
    };
    for (final entry in cases.entries) {
      for (final scrubber in entry.value) {
        test('${entry.key} ${scrubber == saved ? 'saved' : 'unsaved'}', () {
          final out = scrubber.scrub(entry.key);
          for (final leak in leaks) {
            expect(out, isNot(contains(leak)), reason: out);
          }
        });
      }
    }

    test('saved_names_go_before_the_service_rule', () {
      expect(
        saved.scrub("Mike's TV._androidtvremote2._tcp.local."),
        isNot(contains("'s")),
      );
    });
  });

  group('ipv6_fallback', () {
    final s = CrashScrubber();
    test('long_colon_runs_are_addresses', () {
      expect(s.scrub('addr 2001:DB8:85A3:0:0:8A2E:370:7334 x'), 'addr <ip> x');
      expect(s.scrub('addr FE80:0:0:0:1C2B x'), 'addr <ip> x');
      expect(s.scrub('addr 1:2:3:4:5:6:7 x'), 'addr <ip> x');
      expect(s.scrub('addr 1:2:3:4 x'), 'addr <ip> x');
    });
    test('zones_are_removed_including_percent_encoded', () {
      expect(s.scrub('fe80::1%25wlan0 down'), '<ip> down');
      expect(s.scrub('fe80::1%wlan0 down'), '<ip> down');
      expect(s.scrub('FE80::ABCD%25eth0'), '<ip>');
    });
    test('times_and_frames_survive', () {
      for (final text in const [
        'at 12:34:56 today',
        'dart:async/future.dart:100:5',
        '#3 _rootRun (dart:async/zone.dart:1399:13)',
        'package:tv_remote/a.dart:12:34',
      ]) {
        expect(s.scrub(text), text);
      }
    });
  });

  test('scrubs_uuids', () {
    final s = CrashScrubber();
    expect(
      s.scrub('id 123e4567-e89b-12d3-A456-426614174000 gone'),
      'id <id> gone',
    );
    expect(s.scrub('a-b-c'), 'a-b-c');
  });

  test('keeps_ordinary_text', () {
    final s = CrashScrubber(knownTerms: () => const ['Den']);
    for (final text in const [
      'Bad state: Paired without seeing the TV key',
      'decade',
      'port 6466',
      'hidden garden',
      'Null check operator used on a null value',
      "Looking up a deactivated widget's ancestor is unsafe.",
      'package:tv_remote/features/remote/presentation/remote_page.dart:88:12',
      "type 'Null' is not a subtype of type 'String'",
      'Timeout after 0:00:05.000000',
    ]) {
      expect(s.scrub(text), text);
    }
  });

  test('null_and_empty_are_safe', () {
    final s = CrashScrubber();
    expect(s.scrub(null), '');
    expect(s.scrub(''), '');
    final broken = CrashScrubber(knownTerms: () => throw StateError('x'));
    expect(broken.scrub('a'), 'a');
  });
}
