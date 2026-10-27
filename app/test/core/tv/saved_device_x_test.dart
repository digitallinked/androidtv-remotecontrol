import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/tv/saved_device_x.dart';

import '../../helpers/test_devices.dart';

void main() {
  test('to_discovered_tv_keeps_the_announced_name', () {
    final saved = savedTv(nickname: 'Bedroom');
    expect(saved.label, 'Bedroom');
    final tv = saved.toDiscoveredTv();
    expect(tv.displayName, 'Living Room TV 3');
    expect(tv.serviceName, 'Living Room TV 3');
    expect(tv.host, '192.168.0.20');
    expect(tv.port, 6466);
  });
}
