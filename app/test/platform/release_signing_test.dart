import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The file's text with \n line endings (the Windows checkout has CRLF).
String read(String p) => File(p).readAsStringSync().replaceAll('\r\n', '\n');

/// The build script of the app module.
String gradle() => read('android/app/build.gradle.kts');

/// The `KEY=value` lines of a `.properties` file (comments and lines
/// without `=` skipped).
Map<String, String> properties(String text) => {
  for (final line in text.split('\n').map((l) => l.trim()))
    if (line.contains('=') && !line.startsWith('#') && !line.startsWith('!'))
      line.substring(0, line.indexOf('=')).trim(): line
          .substring(line.indexOf('=') + 1)
          .trim(),
};

/// The body of `uploadBundleProblems` in the build script.
String uploadBundleProblems(String script) => RegExp(
  r'val uploadBundleProblems: List<String> = listOfNotNull\((.*?)\n\)',
  dotAll: true,
).firstMatch(script)!.group(1)!;

/// The four keys a usable `key.properties` holds (Ruling P9-R3).
const signingKeys = ['storeFile', 'storePassword', 'keyAlias', 'keyPassword'];

void main() {
  test(
    // The brief's test name, verbatim.
    // ignore: lines_longer_than_80_chars
    'release_signing_reads_key_properties_and_falls_back_to_debug_only_without_it',
    () {
      final script = gradle();
      expect(
        script,
        contains('val keyPropertiesFile = rootProject.file("key.properties")'),
      );
      for (final key in signingKeys) {
        expect(script, contains('"$key"'), reason: key);
      }
      expect(script, contains('val releaseSigningProblem: String?'));

      // The release config exists only when key.properties is usable.
      final signing = RegExp(
        r'\n    signingConfigs \{(.*?)\n    \}',
        dotAll: true,
      ).firstMatch(script);
      expect(signing, isNotNull);
      expect(
        RegExp(
          r'if \(releaseSigningUsable\) \{\s*create\("release"\) \{',
        ).hasMatch(signing!.group(1)!),
        isTrue,
      );
      expect('create("release")'.allMatches(script).length, 1);
      for (final key in signingKeys) {
        expect(signing.group(1), contains('$key = '), reason: key);
      }

      // The release build type takes it, and falls back to the debug key only
      // when it isn't usable.
      final release = RegExp(
        r'buildTypes \{\s*release \{(.*?)\n        \}',
        dotAll: true,
      ).firstMatch(script)!.group(1)!;
      expect(
        release,
        contains(
          'signingConfig = if (releaseSigningUsable) '
          'signingConfigs.getByName("release") '
          'else signingConfigs.getByName("debug")',
        ),
      );
      expect('signingConfigs.getByName("debug")'.allMatches(script).length, 1);
      expect(
        script,
        contains(
          'val releaseSigningUsable = keyPropertiesFile.exists() && '
          'releaseSigningProblem == null',
        ),
      );
    },
  );

  test('a_broken_key_properties_fails_with_a_clear_message', () {
    final script = gradle();
    final problem = RegExp(
      r'val releaseSigningProblem: String\? = when \{(.*?)\n\}',
      dotAll: true,
    ).firstMatch(script);
    expect(problem, isNotNull);
    final body = problem!.group(1)!;
    // Absent is not a problem; it's handled by the bundle rule below.
    expect(body, contains('!keyPropertiesFile.exists() -> null'));
    expect(
      body,
      contains(
        '"android/key.properties is incomplete: '
        r'${missingSigningKeys.joinToString(", ")} missing. '
        'See android/key.properties.example."',
      ),
    );
    expect(
      body,
      contains(
        r'"android/key.properties points at ${releaseStoreFile?.path}, '
        "which doesn't exist. Restore the upload keystore from your backup, "
        'or fix storeFile."',
      ),
    );
    expect(
      script,
      contains(
        'val missingSigningKeys = '
        'signingKeys.filter { keyProperty(it) == null }',
      ),
    );
    // Any requested release task stops on it; debug builds don't.
    expect(
      script,
      contains(
        'val releaseRequested = gradle.startParameter.taskNames.any { '
        'it.contains("release", ignoreCase = true) }',
      ),
    );
    expect(
      script,
      contains(
        'if (release && releaseSigningProblem != null) '
        'throw GradleException(releaseSigningProblem)',
      ),
    );
  });

  test('a_prod_bundle_without_key_properties_or_the_admob_id_is_refused', () {
    final script = gradle();
    expect(
      script,
      contains(
        'val uploadBundleRequested = gradle.startParameter.taskNames.any { '
        r'Regex("(?i)bundle\\w*prod\\w*release").containsMatchIn(it) }',
      ),
    );
    // The regex as Kotlin sees it: the upload bundle only.
    final upload = RegExp(r'bundle\w*prod\w*release', caseSensitive: false);
    expect(upload.hasMatch('bundleProdRelease'), isTrue);
    expect(upload.hasMatch(':app:bundleProdRelease'), isTrue);
    expect(upload.hasMatch('bundleDevRelease'), isFalse);
    expect(upload.hasMatch('assembleProdRelease'), isFalse);
    expect(upload.hasMatch('bundleProdDebug'), isFalse);

    final problems = uploadBundleProblems(script);
    // A broken key.properties is the signing problem; a missing one is the
    // P9-R3 bundle message.
    expect(
      problems,
      contains(
        'releaseSigningProblem\n'
        '        ?: if (!keyPropertiesFile.exists()) "A prod app bundle is the '
        'file you upload to Google Play, so it must be signed with the upload '
        'key: copy android/key.properties.example to android/key.properties '
        'and fill it in (store-release skill). Release APKs and dev bundles '
        'still build, signed with the debug key." else null,',
      ),
    );
    expect(
      problems,
      contains(
        '"A prod app bundle needs the real AdMob app id: set admobAppIdProd '
        'in android/secrets.properties."',
      ),
    );
    // Every other release build is signed with the debug key, and says so.
    expect(
      script,
      contains(
        'if (!keyPropertiesFile.exists() && release)\n'
        '        logger.quiet("release build signed with the debug key (no '
        "android/key.properties); don't upload it.\")",
      ),
    );
    // The rules read the AdMob id, and run before the android block.
    expect(
      script.indexOf('val uploadBundleProblems'),
      greaterThan(script.indexOf('val admobAppIdProd')),
    );
    expect(
      script.indexOf('\nandroid {'),
      greaterThan(script.indexOf('refuseReleaseTasks(releaseRequested')),
    );
  });

  test('the_upload_bundle_refuses_google_s_test_app_id_even_when_set', () {
    // P9-C2 (a): the fallback and an explicit test publisher alike.
    final script = gradle();
    expect(
      script,
      contains(
        'val admobTestPublisherPrefix = "ca-app-pub-3940256099942544~"',
      ),
    );
    expect(
      script,
      contains(
        'val prodUsesTestAdmobId = (admobAppIdProd ?: '
        'admobTestAppId).startsWith(admobTestPublisherPrefix)',
      ),
    );
    expect(uploadBundleProblems(script), contains('if (prodUsesTestAdmobId)'));
  });

  test('the_upload_bundle_refuses_a_malformed_admob_id_on_every_path', () {
    // Task 9.13: in the list, so the task-graph backstop (`gradlew bundle`)
    // refuses it with the same message as the early check.
    expect(
      uploadBundleProblems(gradle()),
      contains('if (admobAppIdMalformed) admobAppIdMalformedMessage else null'),
    );
  });

  test('signing_and_admob_problems_are_reported_together', () {
    // P9-C2 (d): one exception names every problem of the upload bundle.
    final script = gradle();
    expect(
      script,
      contains('val uploadBundleProblems: List<String> = listOfNotNull('),
    );
    expect(
      script,
      contains(
        'if (uploadBundle && uploadBundleProblems.isNotEmpty()) '
        r'throw GradleException(uploadBundleProblems.joinToString("\n"))',
      ),
    );
  });

  test('aggregate_and_abbreviated_tasks_hit_the_same_refusals', () {
    // P9-C2 (c): `gradlew bundle` and `:app:bundleProdRel` name no prod
    // release bundle task, so the task graph is checked too. (`gradlew build`
    // and `assemble` never make a bundle.)
    final script = gradle();
    expect(
      script,
      contains('refuseReleaseTasks(releaseRequested, uploadBundleRequested)'),
    );
    final backstop = RegExp(
      r'\ngradle\.taskGraph\.whenReady \{(.*?)\n\}',
      dotAll: true,
    ).firstMatch(script);
    expect(backstop, isNotNull);
    final body = backstop!.group(1)!;
    expect(
      body,
      contains(
        'val names = allTasks.filter { it.project == project }.map { it.name }',
      ),
    );
    expect(
      body,
      contains('val release = names.any { it.contains("Release") }'),
    );
    expect(
      body,
      contains('refuseReleaseTasks(release, "bundleProdRelease" in names)'),
    );
  });

  test('every_warning_reaches_a_flutter_build', () {
    // `flutter build` runs Gradle with -q, which hides every level below
    // quiet; the script's warnings must still reach the developer.
    expect(
      RegExp(r'logger\.(warn|lifecycle|info|debug)\(').hasMatch(gradle()),
      isFalse,
    );
  });

  test('a_tilde_store_path_means_the_home_directory', () {
    final script = gradle();
    expect(
      script,
      contains(
        'if (path.startsWith("~/")) '
        'File(System.getProperty("user.home"), path.removePrefix("~/"))',
      ),
    );
    // Anything else is absolute or relative to android/.
    expect(script, contains('else rootProject.file(path)'));
    // A directory is not a keystore.
    expect(script, contains('releaseStoreFile?.isFile != true'));
  });

  test('the_example_lists_the_four_keys_with_placeholders', () {
    final text = read('android/key.properties.example');
    expect(properties(text), const {
      'storeFile': '~/keys/atvremote-upload.jks',
      'storePassword': 'CHANGE_ME',
      'keyAlias': 'upload',
      'keyPassword': 'CHANGE_ME',
    });
    expect(
      text,
      contains(
        'keytool -genkeypair -v -keystore ~/keys/atvremote-upload.jks '
        '-keyalg RSA -keysize 4096 -validity 10000 -alias upload',
      ),
    );
    expect(
      text,
      contains('back it up offline; losing it means a Play upload-key reset'),
    );
    // Java's Properties treats a backslash as an escape.
    expect(
      text,
      contains(
        '# Use forward slashes in storeFile even on Windows '
        '(C:/Users/you/keys/upload.jks)',
      ),
    );
  });
}
