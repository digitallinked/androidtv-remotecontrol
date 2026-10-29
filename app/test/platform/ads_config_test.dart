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
      // A blank value or the example's placeholder is "not set", because an
      // empty or malformed app id makes the Mobile Ads provider throw at
      // launch; the test id then stands in.
      expect(
        gradle,
        contains(
          'val admobAppIdProd = secrets.getProperty("admobAppIdProd")?.trim()',
        ),
      );
      expect(
        gradle,
        contains(
          '?.takeIf { it.isNotBlank() && !it.contains("XXXXXXXX") }',
        ),
      );
      expect(
        gradle,
        contains(
          'manifestPlaceholders["admobAppId"] = '
          'admobAppIdProd ?: admobTestAppId',
        ),
      );
      expect(
        gradle,
        contains(
          "prod uses Google's test AdMob app id; "
          'set admobAppIdProd in android/secrets.properties',
        ),
      );
      // The warning is for prod builds only, and says so only when the test
      // id is really used.
      expect(
        gradle,
        contains(
          'val prodRequested = gradle.startParameter.taskNames.any { '
          'it.contains("prod", ignoreCase = true) }',
        ),
      );
      expect(gradle, contains('if (admobAppIdProd == null && prodRequested)'));
      // A malformed prod app id (an ad unit id, say) fails a prod build
      // instead of stopping the app at launch.
      final pattern = RegExp(
        r'val admobAppIdPattern = Regex\("""(.*?)"""\)',
      ).firstMatch(gradle)?.group(1);
      expect(pattern, r'^ca-app-pub-\d{16}~\d{10}$');
      final appId = RegExp(pattern!);
      expect(appId.hasMatch('ca-app-pub-3940256099942544~3347511713'), isTrue);
      expect(appId.hasMatch('ca-app-pub-3940256099942544/9214589741'), isFalse);
      expect(appId.hasMatch('ca-app-pub-3940256099942544~334751171'), isFalse);
      expect(
        gradle,
        contains(
          'if (prodRequested && admobAppIdProd != null && '
          '!admobAppIdPattern.matches(admobAppIdProd))',
        ),
      );
      expect(
        gradle,
        contains(
          'throw GradleException("admobAppIdProd in android/secrets.properties '
          'must be an AdMob app id (ca-app-pub-<16 digits>~<10 digits>), not '
          'an ad unit id; a malformed id stops the app at launch.")',
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
      expect(prod, isNot(contains('getProperty')));

      final example = read('android/secrets.example.properties');
      expect(
        example,
        contains('admobAppIdProd=ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY'),
      );
      expect(example, contains('#'));
      // The placeholder the build treats as "not set".
      expect(example, contains('XXXXXXXX'));
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
    // Every tracked file of the repository: the app, the packages, the docs,
    // the tools and the files at the root. Not working notes (.superpowers/,
    // git-ignored anyway), build output or the Dart tool cache.
    final files = (listing.stdout as String)
        .split('\u0000')
        .where((p) => p.isNotEmpty)
        .where(
          (p) =>
              !p.startsWith('.superpowers/') &&
              !p.contains('/build/') &&
              !p.contains('.dart_tool/'),
        )
        .toList();
    expect(files, isNotEmpty);

    // Google's published test publisher is the only AdMob id the repository
    // may hold. One more is quoted as research data: the competitor's, in
    // its teardown. Only the number is held here, so this file does not match
    // the pattern it scans for.
    const competitorPublisher = '5506461561907650';
    const competitorDocs = 'docs/competitor-analysis/';
    final admob = RegExp(r'ca-app-pub-\d{16}');
    final revenueCat = RegExp('(^|[^a-z])(goog|appl|test)_[A-Za-z0-9]{20,}');
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
      for (final m in admob.allMatches(text)) {
        final id = m.group(0)!;
        final isTestId = id == 'ca-app-pub-3940256099942544';
        final isCompetitor =
            id == 'ca-app-pub-$competitorPublisher' &&
            path.startsWith(competitorDocs);
        if (!isTestId && !isCompetitor) offenders.add('$path: $id');
      }
      if (revenueCat.hasMatch(text)) offenders.add('$path: RevenueCat key');
      if (firebaseKey.hasMatch(text)) offenders.add('$path: Firebase key');
    }
    expect(scanned, greaterThan(50));
    expect(offenders, isEmpty);
    // The scan reads the packages, the tools and the root, not only app/.
    expect(files.any((p) => p.startsWith('packages/')), isTrue);
    expect(files.any((p) => p.startsWith('tool/')), isTrue);
    expect(files.any((p) => !p.contains('/')), isTrue);
  });
}
