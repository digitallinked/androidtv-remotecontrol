import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/tv/manual_tv.dart';

void main() {
  test('manual_ip_parsing_accepts_only_usable_ipv4', () {
    for (final ok in [
      '192.168.1.20',
      ' 10.0.0.5 ',
      '172.16.254.1',
      '1.2.3.4',
    ]) {
      expect(parseIpv4(ok), ok.trim(), reason: ok);
    }
    for (final bad in [
      '',
      '192.168.1',
      '192.168.1.256',
      '192.168.01.2',
      '127.0.0.1',
      '0.1.2.3',
      '224.0.0.1',
      '255.255.255.255',
      'tv.local',
      '::1',
      '1.2.3.4.5',
    ]) {
      expect(parseIpv4(bad), isNull, reason: bad);
    }
  });

  test('manual_tv_uses_prefixed_service_name_and_control_port', () {
    final tv = manualTv('192.168.1.20');
    expect(
      (tv.serviceName, tv.displayName, tv.host, tv.port),
      (
        'manual:192.168.1.20',
        '192.168.1.20',
        '192.168.1.20',
        6466,
      ),
    );
    expect(tv.isLegacyService, isFalse);
    expect(isManualServiceName(tv.serviceName), isTrue);
    expect(isManualServiceName('Living Room TV 3'), isFalse);
  });
}
