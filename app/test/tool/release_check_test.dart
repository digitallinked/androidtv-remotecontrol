import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/ads/ad_unit_ids.dart';

import '../../tool/release_check.dart';
import 'release_fixture.dart';

/// The codes [checkRelease] refuses [root] with.
Future<List<String>> codes(
  Directory root,
  ReleasePlatform platform, {
  ReleaseStage stage = ReleaseStage.pre,
  CertificatePrinter? printCertificate,
  TrackedFileLister? listTrackedFiles,
}) async => [
  for (final r in await refusals(
    root,
    platform,
    stage: stage,
    printCertificate: printCertificate,
    listTrackedFiles: listTrackedFiles,
  ))
    r.code,
];

/// The refusals of [checkRelease] for [root].
Future<List<Refusal>> refusals(
  Directory root,
  ReleasePlatform platform, {
  ReleaseStage stage = ReleaseStage.pre,
  CertificatePrinter? printCertificate,
  TrackedFileLister? listTrackedFiles,
}) => checkRelease(
  root: root,
  platform: platform,
  stage: stage,
  printCertificate: printCertificate ?? uploadSigned,
  listTrackedFiles: listTrackedFiles ?? gitTrackedFiles,
);

/// A certificate printer for a bundle signed with an upload key.
Future<String?> uploadSigned(File _) async =>
    'Signer #1:\n\nSignature:\n\nOwner: CN=Remotely Upload, O=Fixture, C=MY';

/// A certificate printer for a bundle signed with the debug key.
Future<String?> debugSigned(File _) async =>
    'Owner: CN=Android Debug, O=Android, C=US';

/// Defines a test that needs git on the PATH.
void gitTest(String name, Future<void> Function() body) {
  test(name, () async {
    if (!await requireTool('git')) return;
    await body();
  });
}

const _post = <String, String>{FixturePaths.aab: 'not really a bundle'};

void main() {
  gitTest('a_complete_android_tree_passes_the_pre_checks', () async {
    expect(
      await codes(await writeReleaseFixture(), ReleasePlatform.android),
      <String>[],
    );
  });

  gitTest('a_complete_ios_tree_passes_the_pre_checks', () async {
    expect(
      await codes(await writeReleaseFixture(), ReleasePlatform.ios),
      <String>[],
    );
  });

  gitTest('refuses_a_missing_env_file', () async {
    final root = await writeReleaseFixture(omit: {FixturePaths.env});
    expect(await codes(root, ReleasePlatform.android), ['env-missing']);
    expect(await codes(root, ReleasePlatform.ios), ['env-missing']);

    final notAnObject = await writeReleaseFixture(
      files: {FixturePaths.env: '[]'},
    );
    expect(await codes(notAnObject, ReleasePlatform.android), ['env-missing']);
    final notJson = await writeReleaseFixture(files: {FixturePaths.env: '{'});
    expect(await codes(notJson, ReleasePlatform.ios), ['env-missing']);
  });

  gitTest('refuses_firebase_disabled_or_not_a_boolean', () async {
    for (final value in const [false, 'true']) {
      final root = await writeReleaseFixture(env: {'FIREBASE_ENABLED': value});
      for (final platform in ReleasePlatform.values) {
        expect(await codes(root, platform), [
          'firebase-disabled',
        ], reason: '$value on $platform');
      }
    }
  });

  gitTest('refuses_each_missing_service_key_with_its_own_reason', () async {
    const keys = {
      'REVENUECAT_ANDROID_KEY': 'revenuecat-android',
      'REVENUECAT_IOS_KEY': 'revenuecat-ios',
      'ADMOB_BANNER_ANDROID': 'banner-android',
      'ADMOB_BANNER_IOS': 'banner-ios',
    };
    for (final e in keys.entries) {
      final root = await writeReleaseFixture(env: {e.key: ''});
      for (final platform in ReleasePlatform.values) {
        final found = await refusals(root, platform);
        expect(found.map((r) => r.code), [e.value], reason: e.key);
        expect(found.single.message, contains(e.key));
      }
    }
  });

  gitTest(
    'refuses_revenuecat_keys_of_the_wrong_store_or_the_test_store',
    () async {
      for (final value in const ['appl_x', 'test_x']) {
        final root = await writeReleaseFixture(
          env: {'REVENUECAT_ANDROID_KEY': value},
        );
        expect(await codes(root, ReleasePlatform.android), [
          'revenuecat-android',
        ], reason: value);
      }
      final ios = await writeReleaseFixture(
        env: {'REVENUECAT_IOS_KEY': 'goog_x'},
      );
      expect(await codes(ios, ReleasePlatform.ios), ['revenuecat-ios']);
    },
  );

  gitTest('refuses_google_test_ad_units', () async {
    final banner = await writeReleaseFixture(
      env: {'ADMOB_BANNER_ANDROID': AdMobTestIds.androidBanner},
    );
    expect(await codes(banner, ReleasePlatform.android), ['banner-android']);
    final interstitial = await writeReleaseFixture(
      env: {'ADMOB_INTERSTITIAL_IOS': AdMobTestIds.iosInterstitial},
    );
    expect(await codes(interstitial, ReleasePlatform.ios), [
      'interstitial-ios',
    ]);
  });

  gitTest('allows_empty_interstitial_ids', () async {
    final root = await writeReleaseFixture(
      env: {'ADMOB_INTERSTITIAL_ANDROID': '', 'ADMOB_INTERSTITIAL_IOS': ''},
    );
    expect(await codes(root, ReleasePlatform.android), <String>[]);
    expect(await codes(root, ReleasePlatform.ios), <String>[]);
  });

  gitTest('refuses_ump_debug_settings_in_prod', () async {
    const settings = {
      'UMP_DEBUG_GEOGRAPHY': 'eea',
      'UMP_TEST_DEVICE_ID': 'abc',
    };
    for (final e in settings.entries) {
      final root = await writeReleaseFixture(env: {e.key: e.value});
      final found = await refusals(root, ReleasePlatform.android);
      expect(found.map((r) => r.code), ['ump-debug'], reason: e.key);
      expect(found.single.message, contains(e.key));
      expect(found.single.message, isNot(contains(e.value)));
    }
  });

  gitTest('refuses_missing_or_mismatched_firebase_config', () async {
    final noAndroid = await writeReleaseFixture(
      omit: {FixturePaths.googleServices},
    );
    expect(await codes(noAndroid, ReleasePlatform.android), [
      'firebase-android-config',
    ]);
    expect(await codes(noAndroid, ReleasePlatform.ios), <String>[]);
    final otherPackage = await writeReleaseFixture(
      files: {
        FixturePaths.googleServices: fixtureGoogleServices(
          packageName: 'com.other',
        ),
      },
    );
    expect(await codes(otherPackage, ReleasePlatform.android), [
      'firebase-android-config',
    ]);
    final noIos = await writeReleaseFixture(
      omit: {FixturePaths.googleServiceInfo},
    );
    expect(await codes(noIos, ReleasePlatform.ios), ['firebase-ios-config']);
    expect(await codes(noIos, ReleasePlatform.android), <String>[]);
    final otherBundle = await writeReleaseFixture(
      files: {
        FixturePaths.googleServiceInfo: fixtureGoogleServiceInfo(
          bundleId: 'com.other',
        ),
      },
    );
    expect(await codes(otherBundle, ReleasePlatform.ios), [
      'firebase-ios-config',
    ]);
  });

  gitTest(
    'refuses_admob_app_ids_that_are_empty_placeholder_test_or_malformed',
    () async {
      for (final value in const [
        '',
        'ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY',
        AdMobTestIds.androidAppId,
        'ca-app-pub-1234567890123456/1234567890',
      ]) {
        final root = await writeReleaseFixture(
          files: {
            FixturePaths.secretsProperties: fixtureSecretsProperties(
              admobAppIdProd: value,
            ),
            FixturePaths.secretsXcconfig: fixtureSecretsXcconfig(
              admobAppIdProd: value,
            ),
          },
        );
        final android = await refusals(root, ReleasePlatform.android);
        expect(android.map((r) => r.code), [
          'admob-app-android',
        ], reason: value);
        final ios = await refusals(root, ReleasePlatform.ios);
        expect(ios.map((r) => r.code), ['admob-app-ios'], reason: value);
        if (value.isNotEmpty) {
          expect(android.single.message, isNot(contains(value)));
          expect(ios.single.message, isNot(contains(value)));
        }
      }
    },
  );

  gitTest(
    'refuses_android_signing_without_a_complete_key_properties',
    () async {
      final missing = await writeReleaseFixture(
        omit: {FixturePaths.keyProperties},
      );
      final m = await refusals(missing, ReleasePlatform.android);
      expect(m.map((r) => r.code), ['signing']);
      expect(m.single.message, contains('app/android/key.properties'));
      expect(m.single.message, contains('missing'));
      expect(await codes(missing, ReleasePlatform.ios), <String>[]);

      final incomplete = await writeReleaseFixture(
        files: {
          FixturePaths.keyProperties: fixtureKeyProperties(
            drop: {'keyAlias'},
          ),
        },
      );
      final i = await refusals(incomplete, ReleasePlatform.android);
      expect(i.map((r) => r.code), ['signing']);
      expect(i.single.message, contains('keyAlias'));
      expect(i.single.message, isNot(contains('fixture-store-password')));

      final noStore = await writeReleaseFixture(
        files: {
          FixturePaths.keyProperties: fixtureKeyProperties(
            storeFile: 'keys/lost.jks',
          ),
        },
      );
      final s = await refusals(noStore, ReleasePlatform.android);
      expect(s.map((r) => r.code), ['signing']);
      expect(s.single.message, contains('keys/lost.jks'));
      expect(s.single.message, contains("doesn't exist"));
    },
  );

  test('a_tilde_store_path_resolves_to_the_home_directory', () async {
    if (!await requireTool('git') || !await requireTool('dart')) return;
    final root = await writeReleaseFixture(
      files: {
        FixturePaths.keyProperties: fixtureKeyProperties(
          storeFile: '~/x.jks',
        ),
        'x.jks': 'fake',
      },
    );
    final home = {'HOME': root.path, 'USERPROFILE': root.path};
    final result = await runTool(
      'dart',
      ['tool/release_check.dart', '--platform', 'android', '--root', root.path],
      environment: home,
    );
    expect(result.stdout, contains('All android pre release checks passed.'));
    expect(result.exitCode, 0);

    File('${root.path}/x.jks').deleteSync();
    final gone = await runTool(
      'dart',
      ['tool/release_check.dart', '--platform', 'android', '--root', root.path],
      environment: home,
    );
    expect(gone.stdout, contains('REFUSED [signing]'));
    expect(gone.exitCode, 1);
  });

  gitTest('refuses_tracked_secrets', () async {
    final root = await writeReleaseFixture();
    final add = await runTool('git', [
      'add',
      '-f',
      FixturePaths.env,
    ], workingDirectory: root.path);
    expect(add.exitCode, 0, reason: '${add.stderr}');
    final found = await refusals(root, ReleasePlatform.android);
    expect(found.map((r) => r.code), ['secrets-tracked']);
    expect(found.single.message, contains(FixturePaths.env));
    expect(await codes(root, ReleasePlatform.ios), ['secrets-tracked']);
  });

  test('refuses_when_git_cannot_list_files', () async {
    final root = await writeReleaseFixture(gitInit: false);
    final found = await refusals(
      root,
      ReleasePlatform.android,
      listTrackedFiles: (_) async => null,
    );
    expect(found.map((r) => r.code), ['secrets-tracked']);
    expect(found.single.message, contains("git couldn't list"));
  });

  gitTest('refuses_placeholder_links', () async {
    final root = await writeReleaseFixture(
      files: {FixturePaths.appLinks: placeholderAppLinks},
    );
    final found = await refusals(root, ReleasePlatform.android);
    expect(found.map((r) => r.code), ['placeholder-links']);
    for (final which in const ['privacy', 'terms', 'support']) {
      expect(found.single.message, contains(which));
    }
    final onlyTerms = await writeReleaseFixture(
      files: {
        FixturePaths.appLinks: fixtureAppLinks.replaceFirst(
          'legal.remotely.test/terms',
          'example.com/terms',
        ),
      },
    );
    final t = await refusals(onlyTerms, ReleasePlatform.android);
    expect(t.map((r) => r.code), ['placeholder-links']);
    expect(t.single.message, contains('terms'));
    expect(t.single.message, isNot(contains('privacy')));
  });

  gitTest('refuses_the_placeholder_app_store_id_on_ios_only', () async {
    final root = await writeReleaseFixture(
      files: {
        FixturePaths.appLinks: fixtureAppLinks.replaceFirst(
          'id1234567890',
          'id0000000000',
        ),
      },
    );
    expect(await codes(root, ReleasePlatform.ios), ['app-store-id']);
    expect(await codes(root, ReleasePlatform.android), <String>[]);
  });

  gitTest('reports_every_problem_at_once', () async {
    final root = await writeReleaseFixture(
      omit: everyConfigFile,
      files: {FixturePaths.appLinks: placeholderAppLinks},
    );
    expect(await codes(root, ReleasePlatform.android), [
      'env-missing',
      'firebase-android-config',
      'admob-app-android',
      'signing',
      'placeholder-links',
    ]);
    expect(await codes(root, ReleasePlatform.ios), [
      'env-missing',
      'firebase-ios-config',
      'admob-app-ios',
      'placeholder-links',
      'app-store-id',
    ]);
  });

  gitTest('manifest_stage_refuses_a_missing_merged_manifest', () async {
    final root = await writeReleaseFixture();
    expect(
      await codes(root, ReleasePlatform.android, stage: ReleaseStage.manifest),
      ['manifest-missing'],
    );
    expect(
      await codes(root, ReleasePlatform.ios, stage: ReleaseStage.manifest),
      <String>[],
    );
  });

  gitTest('manifest_stage_refuses_each_missing_backup_attribute', () async {
    for (final attribute in const [
      'android:allowBackup',
      'android:fullBackupContent',
      'android:dataExtractionRules',
    ]) {
      final root = await writeReleaseFixture(
        omit: everyConfigFile,
        files: {
          FixturePaths.mergedManifest: fixtureMergedManifest(
            dropAttributes: {attribute},
          ),
        },
      );
      final found = await refusals(
        root,
        ReleasePlatform.android,
        stage: ReleaseStage.manifest,
      );
      expect(found.map((r) => r.code), ['manifest-backup'], reason: attribute);
      expect(found.single.message, contains(attribute));
    }
  });

  gitTest('manifest_stage_refuses_a_target_sdk_below_35', () async {
    for (final (sdk, expected) in const [
      (34, ['manifest-target-sdk']),
      (35, <String>[]),
      (36, <String>[]),
    ]) {
      final root = await writeReleaseFixture(
        files: {
          FixturePaths.mergedManifest: fixtureMergedManifest(targetSdk: sdk),
        },
      );
      expect(
        await codes(
          root,
          ReleasePlatform.android,
          stage: ReleaseStage.manifest,
        ),
        expected,
        reason: '$sdk',
      );
    }
  });

  gitTest('post_stage_refuses_a_missing_bundle', () async {
    final root = await writeReleaseFixture(
      files: {FixturePaths.mergedManifest: fixtureMergedManifest()},
    );
    expect(
      await codes(root, ReleasePlatform.android, stage: ReleaseStage.post),
      ['artifact-missing'],
    );
  });

  gitTest('post_stage_refuses_a_debug_signed_bundle', () async {
    final root = await writeReleaseFixture(
      files: {..._post, FixturePaths.mergedManifest: fixtureMergedManifest()},
    );
    expect(
      await codes(
        root,
        ReleasePlatform.android,
        stage: ReleaseStage.post,
        printCertificate: debugSigned,
      ),
      ['debug-signed'],
    );
    expect(
      await codes(root, ReleasePlatform.android, stage: ReleaseStage.post),
      <String>[],
    );
  });

  gitTest('post_stage_refuses_an_unreadable_signature', () async {
    final root = await writeReleaseFixture(
      files: {..._post, FixturePaths.mergedManifest: fixtureMergedManifest()},
    );
    final found = await refusals(
      root,
      ReleasePlatform.android,
      stage: ReleaseStage.post,
      printCertificate: (_) async => null,
    );
    expect(found.map((r) => r.code), ['debug-signed']);
    expect(
      found.single.message,
      allOf(contains('signature'), contains("couldn't be read")),
    );
  });

  gitTest(
    'post_stage_refuses_the_test_admob_id_in_the_merged_manifest',
    () async {
      final root = await writeReleaseFixture(
        files: {
          ..._post,
          FixturePaths.mergedManifest: fixtureMergedManifest(
            admobAppId: AdMobTestIds.androidAppId,
          ),
        },
      );
      expect(
        await codes(root, ReleasePlatform.android, stage: ReleaseStage.post),
        ['manifest-admob-id'],
      );
      expect(
        await codes(
          root,
          ReleasePlatform.android,
          stage: ReleaseStage.manifest,
        ),
        <String>[],
      );
    },
  );

  gitTest('ios_post_stage_refuses_a_missing_ipa', () async {
    final root = await writeReleaseFixture();
    expect(await codes(root, ReleasePlatform.ios, stage: ReleaseStage.post), [
      'artifact-missing',
    ]);
    final built = await writeReleaseFixture(
      files: {FixturePaths.ipa: 'fake ipa'},
    );
    expect(
      await codes(built, ReleasePlatform.ios, stage: ReleaseStage.post),
      <String>[],
    );
  });

  test('the_real_keytool_printer_returns_null_for_an_unsigned_zip', () async {
    if (!await requireTool('keytool', const ['-help'])) return;
    final dir = Directory.systemTemp.createTempSync('release_fixture_');
    addTearDown(() => dir.deleteSync(recursive: true));
    // An empty zip (end-of-central-directory record only): keytool prints
    // "Not a signed jar file" and exits 0 for it.
    final zip = File('${dir.path}/unsigned.aab')
      ..writeAsBytesSync([0x50, 0x4b, 0x05, 0x06, ...List.filled(18, 0)]);
    expect(await keytoolPrintCertificate(zip), isNull);
  });

  test('tool_output_that_is_not_utf8_is_decoded_leniently', () {
    // "Owner: CN=Jos" + e-acute in Windows-1252, as keytool may print it on
    // a Windows console code page.
    final bytes = [...'Owner: CN=Jos'.codeUnits, 0xe9, ...', O=X'.codeUnits];
    final text = decodeToolOutput(bytes);
    expect(text, startsWith('Owner: CN=Jos'));
    expect(text, endsWith(', O=X'));
    expect(text, contains('\uFFFD'));
  });

  test('refuses_every_never_commit_path_and_exempts_the_example', () async {
    final root = await writeReleaseFixture(gitInit: false);
    Future<List<Refusal>> tracking(List<String> paths) => refusals(
      root,
      ReleasePlatform.android,
      listTrackedFiles: (_) async => paths,
    );
    for (final path in const [
      'keys/upload.jks',
      'app/android/release.keystore',
      'AuthKey_ABC123.p8',
      'app/android/key.properties',
      'app/android/app/src/prod/google-services.json',
      'app/android/app/google-services.json',
      'app/ios/config/prod/GoogleService-Info.plist',
      'app/android/secrets.properties',
      'app/ios/Flutter/Secrets.xcconfig',
      '.env',
      'app/env/prod.json',
      'app/env/dev.json',
    ]) {
      final found = await tracking(['README.md', path]);
      expect(found.map((r) => r.code), ['secrets-tracked'], reason: path);
      expect(found.single.message, contains(path), reason: path);
      expect(found.single.message, isNot(contains('README.md')));
    }
    expect(
      await tracking(const [
        'app/env/example.json',
        'app/android/secrets.example.properties',
        'app/ios/Flutter/Secrets.example.xcconfig',
        'app/android/key.properties.example',
        'app/lib/main_prod.dart',
      ]),
      <Refusal>[],
    );
  });

  test('the_real_git_lister_is_null_outside_a_work_tree', () async {
    if (!await requireTool('git')) return;
    final dir = Directory.systemTemp.createTempSync('release_fixture_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final inside = await runTool('git', const [
      'rev-parse',
      '--is-inside-work-tree',
    ], workingDirectory: dir.path);
    if (inside.exitCode == 0) {
      markTestSkipped('the temp directory is inside a git work tree');
      return;
    }
    expect(await gitTrackedFiles(dir), isNull);
  });

  gitTest('refuses_an_invalid_google_services_json', () async {
    final root = await writeReleaseFixture(
      files: {FixturePaths.googleServices: '{"client": ['},
    );
    final found = await refusals(root, ReleasePlatform.android);
    expect(found.map((r) => r.code), ['firebase-android-config']);
    expect(found.single.message, contains("isn't valid JSON"));
  });

  gitTest('refuses_the_test_unit_as_the_android_interstitial', () async {
    final root = await writeReleaseFixture(
      env: {'ADMOB_INTERSTITIAL_ANDROID': AdMobTestIds.androidInterstitial},
    );
    expect(await codes(root, ReleasePlatform.android), [
      'interstitial-android',
    ]);
  });

  gitTest('refuses_a_malformed_banner_id', () async {
    for (final value in const [
      'ca-app-pub-123/456',
      'ca-app-pub-1234567890123456~1234567890',
      ' ca-app-pub-1234567890123456/1234567890',
    ]) {
      final root = await writeReleaseFixture(env: {'ADMOB_BANNER_IOS': value});
      final found = await refusals(root, ReleasePlatform.ios);
      expect(found.map((r) => r.code), ['banner-ios'], reason: value);
      expect(found.single.message, isNot(contains(value.trim())));
    }
  });

  gitTest('manifest_stage_refuses_a_missing_target_sdk', () async {
    final root = await writeReleaseFixture(
      files: {
        FixturePaths.mergedManifest: fixtureMergedManifest(targetSdk: null),
      },
    );
    expect(
      await codes(root, ReleasePlatform.android, stage: ReleaseStage.manifest),
      ['manifest-target-sdk'],
    );
  });

  gitTest('post_stage_refuses_a_missing_admob_application_id', () async {
    final root = await writeReleaseFixture(
      files: {
        ..._post,
        FixturePaths.mergedManifest: fixtureMergedManifest(admobAppId: null),
      },
    );
    final found = await refusals(
      root,
      ReleasePlatform.android,
      stage: ReleaseStage.post,
    );
    expect(found.map((r) => r.code), ['manifest-admob-id']);
    expect(found.single.message, contains('no AdMob APPLICATION_ID'));
  });

  test('refusal_has_value_equality_and_a_readable_form', () {
    expect(const Refusal('a', 'b'), const Refusal('a', 'b'));
    expect(const Refusal('a', 'b').hashCode, const Refusal('a', 'b').hashCode);
    expect(const Refusal('a', 'b'), isNot(const Refusal('a', 'c')));
    expect(const Refusal('signing', 'x').toString(), 'REFUSED [signing] x');
  });

  test('cli_prints_one_line_per_refusal_and_exits_1', () async {
    if (!await requireTool('git') || !await requireTool('dart')) return;
    final root = await writeReleaseFixture(
      omit: everyConfigFile,
      files: {FixturePaths.appLinks: placeholderAppLinks},
    );
    final result = await runTool('dart', [
      'tool/release_check.dart',
      '--platform',
      'android',
      '--root',
      root.path,
    ]);
    final lines = (result.stdout as String).trim().split(RegExp(r'\r?\n'));
    expect(lines.where((l) => l.startsWith('REFUSED [')), hasLength(5));
    expect(lines.last, '5 problem(s). Fix them before a store build.');
    expect(result.exitCode, 1);
  });

  test('cli_passes_with_exit_0', () async {
    if (!await requireTool('git') || !await requireTool('dart')) return;
    final root = await writeReleaseFixture();
    final result = await runTool('dart', [
      'tool/release_check.dart',
      '--platform',
      'android',
      '--root',
      root.path,
    ]);
    expect(
      (result.stdout as String).trim(),
      'All android pre release checks passed.',
    );
    expect(result.exitCode, 0);
  });

  test('cli_exits_64_on_bad_arguments', () async {
    if (!await requireTool('dart')) return;
    for (final args in const [
      ['--platform', 'windows'],
      <String>[],
      ['--platform', 'android', '--stage', 'later'],
    ]) {
      final result = await runTool('dart', [
        'tool/release_check.dart',
        ...args,
      ]);
      expect(result.exitCode, 64, reason: '$args');
      expect(result.stderr, contains('Usage'), reason: '$args');
    }
  });
}
