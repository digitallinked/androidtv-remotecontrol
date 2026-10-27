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
    // No new permissions: the manifest asks for the same four as before.
    expect(
      RegExp('<uses-permission ').allMatches(manifest),
      hasLength(4),
    );
  });
}
