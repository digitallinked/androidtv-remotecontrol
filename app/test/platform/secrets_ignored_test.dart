import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('secrets_are_git_ignored', () {
    final lines = File(
      '../.gitignore',
    ).readAsLinesSync().map((l) => l.trim()).toSet();
    expect(
      lines,
      containsAll(const [
        'google-services.json',
        'GoogleService-Info.plist',
        'app/env/*.json',
        '!app/env/example.json',
        'app/android/secrets.properties',
        'app/ios/Flutter/Secrets.xcconfig',
        'app/ios/config/',
      ]),
    );
  });

  test('env_example_lists_every_service_key_empty', () {
    final json =
        jsonDecode(File('env/example.json').readAsStringSync())
            as Map<String, Object?>;
    expect(json.keys.toSet(), const {
      '_README',
      'FIREBASE_ENABLED',
      'REVENUECAT_ANDROID_KEY',
      'REVENUECAT_IOS_KEY',
      'ADMOB_BANNER_ANDROID',
      'ADMOB_BANNER_IOS',
      'ADMOB_INTERSTITIAL_ANDROID',
      'ADMOB_INTERSTITIAL_IOS',
      'UMP_DEBUG_GEOGRAPHY',
      'UMP_TEST_DEVICE_ID',
    });
    expect(json['FIREBASE_ENABLED'], false);
    for (final e in json.entries) {
      if (e.key == '_README' || e.key == 'FIREBASE_ENABLED') continue;
      expect(e.value, '', reason: e.key);
    }
  });

  test('secret_paths_are_ignored_by_git_and_the_example_is_not', () {
    final root = Directory('..').absolute.path;
    ProcessResult git(String path) => Process.runSync(
      'git',
      ['check-ignore', '-q', path],
      workingDirectory: root,
    );
    try {
      Process.runSync('git', ['--version']);
    } on ProcessException {
      markTestSkipped('git is not on the PATH');
      return;
    }
    if (!Directory('../.git').existsSync() && !File('../.git').existsSync()) {
      markTestSkipped('not a git checkout');
      return;
    }
    for (final path in const [
      'app/android/app/src/dev/google-services.json',
      'app/android/app/google-services.json',
      'app/ios/config/dev/GoogleService-Info.plist',
      'app/env/dev.json',
      'app/env/prod.json',
      'app/android/secrets.properties',
      'app/ios/Flutter/Secrets.xcconfig',
    ]) {
      expect(git(path).exitCode, 0, reason: '$path must be git-ignored');
    }
    expect(
      git('app/env/example.json').exitCode,
      1,
      reason: 'example.json must be tracked',
    );
  });
}
