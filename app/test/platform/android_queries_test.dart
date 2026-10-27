import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('android_manifest_declares_mailto_and_https_queries', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');

    expect(
      manifest,
      contains(
        '<intent> <action android:name="android.intent.action.SENDTO"/> '
        '<data android:scheme="mailto"/> </intent>',
      ),
    );
    expect(
      manifest,
      contains(
        '<intent> <action android:name="android.intent.action.VIEW"/> '
        '<data android:scheme="https"/> </intent>',
      ),
    );
    // The four network permissions, plus the advertising id that AdMob needs
    // (Ruling P6-R8). Nothing else. `<uses-permission` may be followed by a
    // space or a line break, and `<uses-permission-sdk-23` asks for a
    // permission too.
    final declared = RegExp(
      r'<uses-permission(?:-sdk-23|-sdk-m)?\s[^>]*?android:name="([^"]+)"',
    ).allMatches(manifest).map((m) => m.group(1)).toList();
    expect(declared.toSet(), {
      'android.permission.INTERNET',
      'android.permission.ACCESS_NETWORK_STATE',
      'android.permission.ACCESS_WIFI_STATE',
      'android.permission.CHANGE_WIFI_MULTICAST_STATE',
      'com.google.android.gms.permission.AD_ID',
    });
    expect(declared, hasLength(5));
    // Every tag was read: none declares a name this pattern could miss.
    expect(
      RegExp('<uses-permission').allMatches(manifest),
      hasLength(declared.length),
    );
  });
}
