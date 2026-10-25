import 'package:atv_remote/src/discovery.dart';
import 'package:test/test.dart';

void main() {
  group('parseServiceRecord', () {
    test('parses_v2_service', () {
      final tv = parseServiceRecord(
        serviceType: '_androidtvremote2._tcp',
        name: 'Living Room TV',
        host: '192.168.1.20',
        port: 6466,
      );

      expect(tv.isLegacyService, isFalse);
      expect(tv.serviceName, 'Living Room TV');
      expect(tv.displayName, 'Living Room TV');
      expect(tv.host, '192.168.1.20');
      expect(tv.port, 6466);
    });

    test('parses_legacy_service', () {
      final tv = parseServiceRecord(
        serviceType: '_androidtvremote._tcp',
        name: 'Old TV',
        host: '192.168.1.21',
        port: 6466,
      );

      expect(tv.isLegacyService, isTrue);
    });

    test('accepts trailing dot and .local suffix variants', () {
      for (final type in [
        '_androidtvremote2._tcp.',
        '_androidtvremote2._tcp.local',
        '_androidtvremote2._tcp.local.',
      ]) {
        expect(
          parseServiceRecord(
            serviceType: type,
            name: 'TV',
            host: 'h',
            port: 1,
          ).isLegacyService,
          isFalse,
          reason: type,
        );
      }
      expect(
        parseServiceRecord(
          serviceType: '_androidtvremote._tcp.local.',
          name: 'TV',
          host: 'h',
          port: 1,
        ).isLegacyService,
        isTrue,
      );
    });

    test('rejects other service types', () {
      for (final type in ['_http._tcp', '', '_androidtvremote3._tcp']) {
        expect(
          () => parseServiceRecord(
            serviceType: type,
            name: 'TV',
            host: 'h',
            port: 1,
          ),
          throwsArgumentError,
          reason: type,
        );
      }
    });

    test('displayName is trimmed, serviceName stays raw', () {
      final tv = parseServiceRecord(
        serviceType: '_androidtvremote2._tcp',
        name: '  Bedroom TV \n',
        host: 'h',
        port: 1,
      );

      expect(tv.serviceName, '  Bedroom TV \n');
      expect(tv.displayName, 'Bedroom TV');
    });
  });

  group('DiscoveredTv', () {
    DiscoveredTv make({int port = 6466}) => parseServiceRecord(
      serviceType: '_androidtvremote2._tcp',
      name: 'TV',
      host: '10.0.0.2',
      port: port,
    );

    test('is a value type', () {
      expect(make(), make());
      expect(make().hashCode, make().hashCode);
      expect(make(), isNot(make(port: 1)));
      expect(make().toString(), contains('10.0.0.2'));
    });
  });
}
