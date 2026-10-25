import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ios_declares_local_network_usage_and_bonjour_services', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('<key>NSLocalNetworkUsageDescription</key>'));
    expect(plist, contains('<key>NSBonjourServices</key>'));
    expect(plist, contains('<string>_androidtvremote2._tcp</string>'));
    expect(plist, contains('<string>_androidtvremote._tcp</string>'));
  });
}
