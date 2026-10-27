import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The file's text with \n line endings (the Windows checkout has CRLF).
String read(String p) => File(p).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  test('android_applies_firebase_plugins_only_with_config', () {
    final settings = read('android/settings.gradle.kts');
    expect(
      settings,
      contains(
        'id("com.google.gms.google-services") version "4.5.0" apply false',
      ),
    );
    expect(
      settings,
      contains(
        'id("com.google.firebase.crashlytics") version "3.0.8" apply false',
      ),
    );

    final gradle = read('android/app/build.gradle.kts');
    final plugins = RegExp(
      r'plugins \{(.*?)\n\}',
      dotAll: true,
    ).firstMatch(gradle)!.group(1)!;
    expect(plugins, isNot(contains('google-services')));
    expect(plugins, isNot(contains('crashlytics')));
    expect(gradle, contains(r'src/$it/google-services.json'));
    final block = RegExp(
      r'if \(firebaseFlavors\.isNotEmpty\(\)\) \{(.*?)\n\}',
      dotAll: true,
    ).firstMatch(gradle);
    expect(block, isNotNull);
    expect(block!.group(1), contains('com.google.gms.google-services'));
    expect(block.group(1), contains('com.google.firebase.crashlytics'));
  });

  test('firebase_collection_is_off_until_the_app_turns_it_on', () {
    final manifest = read('android/app/src/main/AndroidManifest.xml');
    for (final name in [
      'firebase_analytics_collection_enabled',
      'firebase_crashlytics_collection_enabled',
      'google_analytics_adid_collection_enabled',
      'google_analytics_default_allow_analytics_storage',
      'google_analytics_default_allow_ad_storage',
      'google_analytics_default_allow_ad_user_data',
      'google_analytics_default_allow_ad_personalization_signals',
    ]) {
      expect(
        RegExp('android:name="$name"\\s+android:value="false"').hasMatch(
          manifest,
        ),
        isTrue,
        reason: name,
      );
    }

    final plist = read('ios/Runner/Info.plist');
    for (final key in [
      'FIREBASE_ANALYTICS_COLLECTION_ENABLED',
      'FirebaseCrashlyticsCollectionEnabled',
      'GOOGLE_ANALYTICS_IDFV_COLLECTION_ENABLED',
      'GOOGLE_ANALYTICS_DEFAULT_ALLOW_ANALYTICS_STORAGE',
      'GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_STORAGE',
      'GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_USER_DATA',
      'GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS',
    ]) {
      expect(
        RegExp('<key>$key</key>\\s*<false/>').hasMatch(plist),
        isTrue,
        reason: key,
      );
    }
  });

  test('ios_deployment_target_is_15', () {
    final pbx = read('ios/Runner.xcodeproj/project.pbxproj');
    expect(pbx, isNot(contains('IPHONEOS_DEPLOYMENT_TARGET = 13.0;')));
    expect('IPHONEOS_DEPLOYMENT_TARGET = 15.0;'.allMatches(pbx).length, 9);
  });

  test('ios_copies_firebase_config_per_flavor', () {
    final pbx = read('ios/Runner.xcodeproj/project.pbxproj');
    final phase = RegExp(
      r'(\w{24}) /\* Copy Firebase config \*/ = \{(.*?)\n\t\t\};',
      dotAll: true,
    ).firstMatch(pbx);
    expect(phase, isNotNull);
    final id = phase!.group(1)!;
    expect(phase.group(2), contains('isa = PBXShellScriptBuildPhase;'));
    expect(phase.group(2), contains('alwaysOutOfDate = 1;'));
    expect(
      phase.group(2),
      contains(r'/bin/sh \"$SRCROOT/scripts/copy_firebase_config.sh\"'),
    );
    expect(id.allMatches(pbx).length, 2, reason: 'definition + one reference');

    // It sits in Runner's buildPhases, after Resources.
    final runner = RegExp(
      r'buildPhases = \(\n(\t+9740EEB61CF901F6004384FC.*?)\);',
      dotAll: true,
    ).firstMatch(pbx)!.group(1)!;
    final lines = runner.split('\n').map((l) => l.trim()).toList();
    final resources = lines.indexWhere((l) => l.contains('/* Resources */'));
    final copy = lines.indexWhere((l) => l.contains('Copy Firebase config'));
    expect(resources, isNonNegative);
    expect(copy, greaterThan(resources));

    final script = read('ios/scripts/copy_firebase_config.sh');
    expect(script, contains('set -e'));
    expect(script, contains(r'${CONFIGURATION##*-}'));
    expect(script, contains('-f '));
    expect(script, contains('GoogleService-Info.plist'));
    expect(
      script,
      contains(r'note: no Firebase config for $flavor; Firebase stays off'),
    );
    expect(script, contains('exit 0'));
  });
}
