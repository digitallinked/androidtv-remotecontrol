import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Google's published test app ids (not real ones).
const _androidTestAppId = 'ca-app-pub-3940256099942544~3347511713';
const _iosTestAppId = 'ca-app-pub-3940256099942544~1458002511';

/// The file's text with \n line endings (the Windows checkout has CRLF).
String read(String p) => File(p).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  test('android_declares_the_admob_app_id_and_delays_measurement', () {
    final manifest = read('android/app/src/main/AndroidManifest.xml');
    expect(
      manifest,
      contains(
        '<uses-permission '
        'android:name="com.google.android.gms.permission.AD_ID" />',
      ),
    );
    expect(
      RegExp(
        r'android:name="com\.google\.android\.gms\.ads\.APPLICATION_ID"\s+'
        r'android:value="\$\{admobAppId\}"',
      ).hasMatch(manifest),
      isTrue,
    );
    expect(
      RegExp(
        r'android:name="com\.google\.android\.gms\.ads\.'
        r'DELAY_APP_MEASUREMENT_INIT"\s+android:value="true"',
      ).hasMatch(manifest),
      isTrue,
    );
    // Task 6.4's switches stay: Firebase reports no screens by itself, and
    // the ad id is not used for analytics.
    for (final name in [
      'google_analytics_automatic_screen_reporting_enabled',
      'google_analytics_adid_collection_enabled',
    ]) {
      expect(
        RegExp('android:name="$name"\\s+android:value="false"').hasMatch(
          manifest,
        ),
        isTrue,
        reason: name,
      );
    }
  });

  test(
    'android_dev_uses_the_test_app_id_and_prod_reads_secrets_with_a_fallback',
    () {
      final gradle = read('android/app/build.gradle.kts');
      expect(gradle, contains('val admobTestAppId = "$_androidTestAppId"'));
      expect(gradle, contains('rootProject.file("secrets.properties")'));
      expect(
        gradle,
        contains('manifestPlaceholders["admobAppId"] = admobTestAppId'),
      );
      expect(
        gradle,
        contains(
          'manifestPlaceholders["admobAppId"] = '
          'secrets.getProperty("admobAppIdProd") ?: admobTestAppId',
        ),
      );
      expect(
        gradle,
        contains(
          "prod uses Google's test AdMob app id; "
          'set admobAppIdProd in android/secrets.properties',
        ),
      );
      // Each placeholder sits in its own flavor.
      final dev = RegExp(
        r'create\("dev"\) \{(.*?)\n        \}',
        dotAll: true,
      ).firstMatch(gradle)!.group(1)!;
      final prod = RegExp(
        r'create\("prod"\) \{(.*?)\n        \}',
        dotAll: true,
      ).firstMatch(gradle)!.group(1)!;
      expect(dev, contains('admobTestAppId'));
      expect(dev, isNot(contains('secrets')));
      expect(prod, contains('admobAppIdProd'));

      final example = read('android/secrets.example.properties');
      expect(
        example,
        contains('admobAppIdProd=ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY'),
      );
      expect(example, contains('#'));
    },
  );

  test('ios_declares_tracking_and_admob_keys', () {
    final plist = read('ios/Runner/Info.plist');
    expect(
      RegExp(
        r'<key>GADApplicationIdentifier</key>\s*'
        r'<string>\$\(ADMOB_APP_ID\)</string>',
      ).hasMatch(plist),
      isTrue,
    );
    expect(
      RegExp(
        r'<key>GADDelayAppMeasurementInit</key>\s*<true/>',
      ).hasMatch(plist),
      isTrue,
    );
    expect(
      RegExp(
        r'<key>NSUserTrackingUsageDescription</key>\s*'
        '<string>Remotely uses this to show ads that are more relevant to '
        'you. The app shows the same number of ads whatever you choose.'
        '</string>',
      ).hasMatch(plist),
      isTrue,
    );
    expect(
      RegExp(
        r'<key>SKAdNetworkItems</key>\s*<array>.*?'
        r'<key>SKAdNetworkIdentifier</key>\s*'
        r'<string>cstr6suwn9\.skadnetwork</string>',
        dotAll: true,
      ).hasMatch(plist),
      isTrue,
    );
    // Task 6.4's switch stays.
    expect(
      RegExp(
        r'<key>FirebaseAutomaticScreenReportingEnabled</key>\s*<false/>',
      ).hasMatch(plist),
      isTrue,
    );
  });

  test('ios_dev_configs_use_the_test_app_id', () {
    final project = read('ios/Runner.xcodeproj/project.pbxproj');
    // The six Runner configurations are the ones with an APP_DISPLAY_NAME.
    final blocks = RegExp(
      r'buildSettings = \{(?:(?!\n\t\t\t\};).)*?APP_DISPLAY_NAME = '
      r'"([^"]+)";.*?\n\t\t\t\};',
      dotAll: true,
    ).allMatches(project).toList();
    expect(blocks, hasLength(6));
    var dev = 0;
    var prod = 0;
    for (final block in blocks) {
      final text = block.group(0)!;
      if (block.group(1) == 'Remotely Dev') {
        dev++;
        expect(text, contains('ADMOB_APP_ID = "$_iosTestAppId";'));
      } else {
        prod++;
        expect(text, contains(r'ADMOB_APP_ID = "$(ADMOB_APP_ID_PROD)";'));
      }
    }
    expect((dev, prod), (3, 3));

    for (final name in ['Debug', 'Release']) {
      final xcconfig = read('ios/Flutter/$name.xcconfig');
      expect(xcconfig, contains('ADMOB_APP_ID_PROD = $_iosTestAppId'));
      expect(xcconfig, contains('#include "Generated.xcconfig"'));
      // The optional include comes last, so it can override the default.
      expect(
        xcconfig.trimRight().split('\n').last,
        '#include? "Secrets.xcconfig"',
      );
    }
    final example = read('ios/Flutter/Secrets.example.xcconfig');
    expect(
      example,
      contains('ADMOB_APP_ID_PROD = ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY'),
    );
  });

  test('no_real_admob_ids_committed', () {
    final root = Directory.current.parent.path;
    final listing = Process.runSync('git', [
      'ls-files',
      '-z',
    ], workingDirectory: root);
    expect(listing.exitCode, 0, reason: '${listing.stderr}');
    final files = (listing.stdout as String)
        .split('\u0000')
        .where((p) => p.startsWith('app/') || p.startsWith('docs/'))
        .toList();
    expect(files, isNotEmpty);

    final admob = RegExp(r'ca-app-pub-\d{16}');
    final revenueCat = RegExp('(^|[^a-z])(goog|appl)_[A-Za-z0-9]{20,}');
    final firebaseKey = RegExp('AIza[0-9A-Za-z_-]{35}');
    final offenders = <String>[];
    var scanned = 0;
    for (final path in files) {
      final file = File('$root/$path');
      if (!file.existsSync()) continue; // deleted in the working tree
      final String text;
      try {
        text = utf8.decode(file.readAsBytesSync());
      } on FormatException {
        continue; // binary
      }
      scanned++;
      // The competitor teardown quotes another publisher's ids as research
      // data; they are not ours and are not in any build.
      final isTeardown = path.startsWith('docs/competitor-analysis/');
      for (final m in admob.allMatches(text)) {
        if (!isTeardown && m.group(0) != 'ca-app-pub-3940256099942544') {
          offenders.add('$path: ${m.group(0)}');
        }
      }
      if (revenueCat.hasMatch(text)) offenders.add('$path: RevenueCat key');
      if (firebaseKey.hasMatch(text)) offenders.add('$path: Firebase key');
    }
    expect(scanned, greaterThan(50));
    expect(offenders, isEmpty);
  });
}
