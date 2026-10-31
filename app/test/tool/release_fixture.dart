import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Repo-relative paths of the files a release fixture writes.
abstract final class FixturePaths {
  /// The prod Dart defines.
  static const env = 'app/env/prod.json';

  /// The prod Firebase config for Android.
  static const googleServices = 'app/android/app/src/prod/google-services.json';

  /// The prod Firebase config for iOS.
  static const googleServiceInfo =
      'app/ios/config/prod/GoogleService-Info.plist';

  /// The Android AdMob app id file.
  static const secretsProperties = 'app/android/secrets.properties';

  /// The iOS AdMob app id file.
  static const secretsXcconfig = 'app/ios/Flutter/Secrets.xcconfig';

  /// The Android signing config.
  static const keyProperties = 'app/android/key.properties';

  /// The dummy upload keystore that [keyProperties] points at.
  static const uploadKeystore = 'app/android/upload.jks';

  /// The flavor definitions (prod application id).
  static const flavor = 'app/lib/app/flavor.dart';

  /// The legal and support links.
  static const appLinks = 'app/lib/app/app_links.dart';

  /// The fixture's git-ignore rules.
  static const gitignore = '.gitignore';

  /// A merged prodRelease manifest, as AGP writes it.
  static const mergedManifest =
      'app/build/app/intermediates/merged_manifest/prodRelease/'
      'processProdReleaseMainManifest/AndroidManifest.xml';

  /// The Android upload artifact.
  static const aab =
      'app/build/app/outputs/bundle/prodRelease/app-prod-release.aab';

  /// An iOS upload artifact.
  static const ipa = 'app/build/ios/ipa/Remotely.ipa';

  /// Every file [writeReleaseFixture] writes by default.
  static const all = <String>{
    env,
    googleServices,
    googleServiceInfo,
    secretsProperties,
    secretsXcconfig,
    keyProperties,
    uploadKeystore,
    flavor,
    appLinks,
    gitignore,
  };
}

/// The prod application id in the fixture's `flavor.dart`.
const fixtureProdId = 'com.digitallinked.atvremote';

/// A well-formed, fake AdMob app id (not a secret).
const fakeAdmobAppId = 'ca-app-pub-1234567890123456~1234567890';

/// A well-formed, fake AdMob ad unit id (not a secret).
const fakeAdmobUnitId = 'ca-app-pub-1234567890123456/1234567890';

/// The complete, valid prod defines of a fixture.
const fixtureEnv = <String, Object?>{
  'FIREBASE_ENABLED': true,
  'REVENUECAT_ANDROID_KEY': 'goog_fixtureAndroidKey',
  'REVENUECAT_IOS_KEY': 'appl_fixtureIosKey',
  'ADMOB_BANNER_ANDROID': fakeAdmobUnitId,
  'ADMOB_BANNER_IOS': fakeAdmobUnitId,
  'ADMOB_INTERSTITIAL_ANDROID': fakeAdmobUnitId,
  'ADMOB_INTERSTITIAL_IOS': fakeAdmobUnitId,
  'UMP_DEBUG_GEOGRAPHY': '',
  'UMP_TEST_DEVICE_ID': '',
};

/// A miniature `flavor.dart` with the same shape as the app's.
const fixtureFlavorDart =
    '''
enum Flavor {
  dev(
    displayName: 'Remotely Dev',
    applicationId: 'com.digitallinked.atvremote.dev',
  ),
  prod(
    displayName: 'Remotely for Android TV',
    applicationId: '$fixtureProdId',
  );

  const Flavor({required this.displayName, required this.applicationId});
  final String displayName;
  final String applicationId;
}
''';

/// An `app_links.dart` whose links are all real (non-placeholder).
const fixtureAppLinks = '''
abstract final class AppLinks {
  static final Uri privacyPolicy = Uri.parse('https://legal.remotely.test/privacy');
  static final Uri terms = Uri.parse('https://legal.remotely.test/terms');
  static const String supportEmail = 'help@remotely.test';
  static final Uri appStoreListing = Uri.parse(
    'https://apps.apple.com/app/id1234567890',
  );
}
''';

/// An `app_links.dart` that still has every placeholder, like today's app.
const placeholderAppLinks = '''
abstract final class AppLinks {
  static final Uri privacyPolicy = Uri.parse('https://example.com/privacy');
  static final Uri terms = Uri.parse('https://example.com/terms');
  static const String supportEmail = 'support@example.com';
  static final Uri appStoreListing = Uri.parse(
    'https://apps.apple.com/app/id0000000000',
  );
}
''';

/// The fixture's git-ignore rules: the never-commit list.
const fixtureGitignore = '''
*.jks
*.keystore
key.properties
google-services.json
GoogleService-Info.plist
app/env/*.json
!app/env/example.json
secrets.properties
Secrets.xcconfig
.env
build/
''';

/// A `google-services.json` with an Android client for [packageName].
String fixtureGoogleServices({String packageName = fixtureProdId}) =>
    const JsonEncoder.withIndent('  ').convert({
      'project_info': {'project_id': 'remotely-fixture'},
      'client': [
        {
          'client_info': {
            'mobilesdk_app_id': '1:000000000000:android:0000000000000000',
            'android_client_info': {'package_name': packageName},
          },
        },
      ],
    });

/// A `GoogleService-Info.plist` whose `BUNDLE_ID` is [bundleId].
String fixtureGoogleServiceInfo({String bundleId = fixtureProdId}) =>
    '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>PROJECT_ID</key>
	<string>remotely-fixture</string>
	<key>BUNDLE_ID</key>
	<string>$bundleId</string>
</dict>
</plist>
''';

/// An Android `secrets.properties` with [admobAppIdProd].
String fixtureSecretsProperties({String admobAppIdProd = fakeAdmobAppId}) =>
    '# Fixture values, not secrets.\nadmobAppIdProd=$admobAppIdProd\n';

/// An iOS `Secrets.xcconfig` with [admobAppIdProd].
String fixtureSecretsXcconfig({String admobAppIdProd = fakeAdmobAppId}) =>
    '// Fixture values, not secrets.\nADMOB_APP_ID_PROD = $admobAppIdProd\n';

/// A `key.properties` with every key, pointing at [storeFile]. Keys in [drop]
/// are left out.
String fixtureKeyProperties({
  String storeFile = 'upload.jks',
  Set<String> drop = const {},
}) {
  final values = {
    'storeFile': storeFile,
    'storePassword': 'fixture-store-password',
    'keyAlias': 'upload',
    'keyPassword': 'fixture-key-password',
  }..removeWhere((key, _) => drop.contains(key));
  return [
    '# Fixture values, not secrets.',
    for (final e in values.entries) '${e.key}=${e.value}',
    '',
  ].join('\n');
}

/// A merged prodRelease manifest. Attributes named in [dropAttributes]
/// (`android:allowBackup`, `android:fullBackupContent`,
/// `android:dataExtractionRules`) are left out of `<application>`.
String fixtureMergedManifest({
  Set<String> dropAttributes = const {},
  int targetSdk = 36,
  String admobAppId = fakeAdmobAppId,
}) {
  final attributes = {
    'android:name': 'android.app.Application',
    'android:allowBackup': 'false',
    'android:dataExtractionRules': '@xml/data_extraction_rules',
    'android:fullBackupContent': 'false',
    'android:label': 'Remotely for Android TV',
  }..removeWhere((key, _) => dropAttributes.contains(key));
  return '''
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="$fixtureProdId" >

    <uses-sdk
        android:minSdkVersion="24"
        android:targetSdkVersion="$targetSdk" />

    <application
${attributes.entries.map((e) => '        ${e.key}="${e.value}"').join('\n')} >
        <meta-data
            android:name="com.google.android.gms.ads.APPLICATION_ID"
            android:value="$admobAppId" />
    </application>

</manifest>
''';
}

/// Writes a complete release tree into a new temp directory and deletes it
/// when the test ends.
///
/// The tree has `app/env/prod.json` ([fixtureEnv], with [env] overriding
/// keys), both prod Firebase files, both AdMob app id files, a complete
/// `key.properties` with an existing dummy `upload.jks`, a mini `flavor.dart`
/// and an `app_links.dart` with real links. Merged manifests and artifacts
/// are written only through [files], which adds or replaces files by
/// repo-relative path. Paths in [omit] are left out. With [gitInit], the
/// tree becomes a git work tree with everything not ignored staged.
Directory writeReleaseFixture({
  Set<String> omit = const {},
  Map<String, Object?> env = const {},
  Map<String, String> files = const {},
  bool gitInit = true,
}) {
  final root = Directory.systemTemp.createTempSync('release_fixture_');
  addTearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });
  final contents =
      <String, String>{
          FixturePaths.env: const JsonEncoder.withIndent(
            '  ',
          ).convert({...fixtureEnv, ...env}),
          FixturePaths.googleServices: fixtureGoogleServices(),
          FixturePaths.googleServiceInfo: fixtureGoogleServiceInfo(),
          FixturePaths.secretsProperties: fixtureSecretsProperties(),
          FixturePaths.secretsXcconfig: fixtureSecretsXcconfig(),
          FixturePaths.keyProperties: fixtureKeyProperties(),
          FixturePaths.uploadKeystore: 'fake',
          FixturePaths.flavor: fixtureFlavorDart,
          FixturePaths.appLinks: fixtureAppLinks,
          FixturePaths.gitignore: fixtureGitignore,
        }
        ..removeWhere((path, _) => omit.contains(path))
        ..addAll(files);
  for (final e in contents.entries) {
    File('${root.path}/${e.key}')
      ..createSync(recursive: true)
      ..writeAsStringSync(e.value);
  }
  if (gitInit) {
    for (final args in const [
      ['init', '-q'],
      ['add', '-A'],
    ]) {
      final result = Process.runSync('git', args, workingDirectory: root.path);
      if (result.exitCode != 0) {
        throw StateError('git ${args.join(' ')} failed: ${result.stderr}');
      }
    }
  }
  return root;
}

/// Every default fixture path except `flavor.dart` and `app_links.dart`: the
/// tree of someone who has filled in nothing.
Set<String> get everyConfigFile => FixturePaths.all.difference(const {
  FixturePaths.flavor,
  FixturePaths.appLinks,
});

/// Whether [tool] runs; marks the test skipped (`<tool> is not on the PATH`)
/// when it doesn't.
bool requireTool(
  String tool, [
  List<String> versionArgs = const ['--version'],
]) {
  try {
    Process.runSync(tool, versionArgs);
    return true;
  } on ProcessException {
    markTestSkipped('$tool is not on the PATH');
    return false;
  }
}

/// Runs [executable] with a 60 s timeout, killing it when the time is up.
Future<ProcessResult> runTool(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
  );
  final out = process.stdout.transform(systemEncoding.decoder).join();
  final err = process.stderr.transform(systemEncoding.decoder).join();
  final int code;
  try {
    code = await process.exitCode.timeout(const Duration(seconds: 60));
  } on TimeoutException {
    process.kill();
    rethrow;
  }
  return ProcessResult(process.pid, code, await out, await err);
}
