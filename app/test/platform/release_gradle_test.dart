// Gradle's dry run (-m) configures the build and computes the task graph
// without running a task. That is where every signing and AdMob refusal of
// android/app/build.gradle.kts lives, so this checks them for real (Rulings
// P9-R3, P9-R4, P9-C2) in seconds on a warm daemon.
@Tags(['gradle'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// How long one Gradle dry run may take.
const gradleTimeout = Duration(seconds: 120);

/// The P9-R3 refusal of a prod bundle without `key.properties`.
const noUploadKey =
    'A prod app bundle is the file you upload to Google Play, so it must be '
    'signed with the upload key';

/// The P9-R4 refusal of a prod bundle with Google's test app id.
const testAdmobId = 'A prod app bundle needs the real AdMob app id';

/// The warning of a release build signed with the debug key.
const debugKey = 'release build signed with the debug key';

/// The warning of a prod build that uses the test app id, as the fallback
/// or set explicitly.
const admobFallback = "prod uses Google's test AdMob app id";

/// The refusal of a prod build whose app id isn't one (an ad unit id).
const malformedAdmobId =
    'admobAppIdProd in android/secrets.properties must be an AdMob app id';

/// Google's published test ids: a test app id, and a test banner unit id,
/// which is not an app id. Neither is a secret.
const googleTestAppId = 'ca-app-pub-3940256099942544~3347511713';
const googleTestUnitId = 'ca-app-pub-3940256099942544/9214589741';

/// Why this machine can't run the dry runs, or `null` when it can.
Future<String?> skipReason() async {
  for (final name in ['key.properties', 'secrets.properties']) {
    if (File('android/$name').existsSync()) {
      return 'android/$name exists; the dry runs expect neither local file';
    }
  }
  final wrapper = Platform.isWindows ? 'gradlew.bat' : 'gradlew';
  if (!File('android/$wrapper').existsSync()) {
    return 'android/$wrapper is missing (a flutter build creates it)';
  }
  if (!File('android/local.properties').existsSync()) {
    return 'android/local.properties is missing (a flutter build, or '
        '`flutter build apk --config-only`, writes it with the Flutter SDK '
        'path)';
  }
  if ((Platform.environment['JAVA_HOME'] ?? '').isEmpty) {
    try {
      await Process.run('java', ['-version']).timeout(gradleTimeout);
    } on ProcessException {
      return 'java is not on the PATH';
    }
  }
  return null;
}

/// The exit code and the whole output of `gradlew -q -m <task>`.
Future<(int, String)> dryRun(String task) async {
  final args = ['-q', '-m', task];
  final process = Platform.isWindows
      ? await Process.start(
          // cmd doesn't look for it in the working directory.
          File('android/gradlew.bat').absolute.path,
          args,
          workingDirectory: 'android',
          runInShell: true,
        )
      : await Process.start('bash', [
          'gradlew',
          ...args,
        ], workingDirectory: 'android');
  final out = StringBuffer();
  final done = [
    process.stdout.transform(const SystemEncoding().decoder).forEach(out.write),
    process.stderr.transform(const SystemEncoding().decoder).forEach(out.write),
  ];
  final int code;
  try {
    code = await process.exitCode.timeout(gradleTimeout);
  } on TimeoutException {
    process.kill();
    fail('gradlew -m $task took longer than $gradleTimeout:\n$out');
  }
  await Future.wait(done);
  return (code, LineSplitter.split(out.toString()).join('\n'));
}

void main() {
  late final String? skip;
  setUpAll(() async => skip = await skipReason());

  /// A test that runs one dry run, unless this machine can't. With
  /// [admobAppIdProd], the run sees a git-ignored `secrets.properties`
  /// holding it, deleted again when the test ends.
  void dryRunTest(
    String name,
    String task,
    void Function(int, String) check, {
    String? admobAppIdProd,
  }) {
    test(name, () async {
      if (skip != null) {
        markTestSkipped(skip!);
        return;
      }
      if (admobAppIdProd != null) {
        final secrets = File('android/secrets.properties')
          ..writeAsStringSync('admobAppIdProd=$admobAppIdProd\n');
        addTearDown(secrets.deleteSync);
      }
      final (code, output) = await dryRun(task);
      check(code, output);
    }, timeout: const Timeout(Duration(minutes: 3)));
  }

  dryRunTest(
    'the_prod_bundle_is_refused_with_both_problems',
    ':app:bundleProdRelease',
    (code, output) {
      expect(code, isNot(0), reason: output);
      expect(output, contains(noUploadKey));
      expect(output, contains(testAdmobId));
    },
  );

  dryRunTest(
    'the_prod_release_apk_builds_with_both_warnings',
    ':app:assembleProdRelease',
    (code, output) {
      expect(code, 0, reason: output);
      expect(output, contains(debugKey));
      expect(output, contains(admobFallback));
    },
  );

  dryRunTest(
    'the_dev_bundle_builds',
    ':app:bundleDevRelease',
    (code, output) {
      expect(code, 0, reason: output);
      expect(output, contains(debugKey));
      expect(output, isNot(contains(noUploadKey)));
    },
  );

  dryRunTest(
    'the_aggregate_bundle_task_is_refused',
    'bundle',
    (code, output) {
      expect(code, isNot(0), reason: output);
      expect(output, contains(noUploadKey));
      expect(output, contains(testAdmobId));
    },
  );

  dryRunTest(
    'an_abbreviated_prod_bundle_task_is_refused',
    ':app:bundleProdRel',
    (code, output) {
      expect(code, isNot(0), reason: output);
      expect(output, contains(noUploadKey));
    },
  );

  // Task 9.13: the backstop refuses a malformed id too. `bundle` names no
  // prod task, so only the task-graph check can catch it.
  dryRunTest(
    'the_aggregate_bundle_task_refuses_a_malformed_admob_id',
    'bundle',
    (code, output) {
      expect(code, isNot(0), reason: output);
      expect(output, contains(malformedAdmobId));
      expect(output, contains(noUploadKey));
    },
    admobAppIdProd: googleTestUnitId,
  );

  dryRunTest(
    'a_prod_release_apk_with_the_test_id_set_explicitly_warns',
    ':app:assembleProdRelease',
    (code, output) {
      expect(code, 0, reason: output);
      expect(output, contains(admobFallback));
    },
    admobAppIdProd: googleTestAppId,
  );
}
