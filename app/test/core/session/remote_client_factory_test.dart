import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/flavor.dart';
import 'package:tv_remote/core/config/app_version.dart';
import 'package:tv_remote/core/session/remote_client_factory.dart';

void main() {
  test('app_version_matches_pubspec', () {
    final v = RegExp(
      r'^version: (\S+)\+',
      multiLine: true,
    ).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1);
    expect(kAppVersion, v);
  });

  test('device_info_uses_flavor_application_id', () {
    final dev = deviceInfoFor(Flavor.dev);
    expect(dev.packageName, 'com.digitallinked.atvremote.dev');
    expect(dev.model, 'Remotely');
    expect(dev.model, kRemoteClientName);
    expect(dev.vendor, 'digitallinked');
    expect(dev.appVersion, kAppVersion);
    expect(
      deviceInfoFor(Flavor.prod).packageName,
      'com.digitallinked.atvremote',
    );
  });
}
