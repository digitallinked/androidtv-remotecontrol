// The release checker (Ruling P9-R2). Run from `app/`:
//
//   dart tool/release_check.dart --platform android|ios
//       [--stage pre|manifest|post] [--root <repo>]
//
// It refuses a store build whose tree is missing any config, key or real id,
// and reports every problem in one run. It never prints a secret's value,
// only the name of the key or file. Only `dart:` imports, so it runs without
// `pub get`.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// The store a build is for.
enum ReleasePlatform {
  /// Google Play (an app bundle).
  android,

  /// The App Store (an IPA).
  ios,
}

/// When the checks run.
enum ReleaseStage {
  /// Before the build: config, keys and ids.
  pre,

  /// After a prodRelease manifest merge: the merged Android manifest only.
  manifest,

  /// After the build: the merged manifest and the upload artifact.
  post,
}

/// One reason a store build is refused.
final class Refusal {
  /// Creates a refusal with a stable [code] and a plain-words [message].
  const Refusal(this.code, this.message);

  /// The stable code, such as `env-missing`.
  final String code;

  /// What is wrong and how to fix it. Never contains a secret value.
  final String message;

  @override
  // Both fields are final strings; a dart:-only tool can't import `meta`
  // for @immutable.
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  bool operator ==(Object other) =>
      other is Refusal && other.code == code && other.message == message;

  @override
  // Same reason as `==`.
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  int get hashCode => Object.hash(code, message);

  @override
  String toString() => 'REFUSED [$code] $message';
}

/// Prints the signing certificate of [artifact], or returns `null` when the
/// signature can't be read.
typedef CertificatePrinter = Future<String?> Function(File artifact);

/// Lists the files git tracks under [root] (relative, `/`-separated), or
/// returns `null` when git can't list them.
typedef TrackedFileLister = Future<List<String>?> Function(Directory root);

const _timeout = Duration(seconds: 60);

/// Runs [executable], killing it after 60 s. `null` when it can't start or
/// times out.
Future<ProcessResult?> _run(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) async {
  final Process process;
  try {
    process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
    );
  } on ProcessException {
    return null;
  }
  final out = process.stdout.transform(utf8.decoder).join();
  final err = process.stderr.transform(utf8.decoder).join();
  try {
    final code = await process.exitCode.timeout(_timeout);
    return ProcessResult(process.pid, code, await out, await err);
  } on TimeoutException {
    process.kill();
    return null;
  }
}

/// Runs `keytool -printcert -jarfile <artifact>`, with keytool from
/// `JAVA_HOME/bin`, then the `PATH`. Returns `null` when keytool is missing,
/// fails, or finds no certificate.
Future<String?> keytoolPrintCertificate(File artifact) async {
  final javaHome = Platform.environment['JAVA_HOME'];
  var keytool = 'keytool';
  if (javaHome != null && javaHome.isNotEmpty) {
    final exe = Platform.isWindows ? 'keytool.exe' : 'keytool';
    final candidate = File(
      '$javaHome${Platform.pathSeparator}bin'
      '${Platform.pathSeparator}$exe',
    );
    if (candidate.existsSync()) keytool = candidate.path;
  }
  final result = await _run(keytool, [
    '-printcert',
    '-jarfile',
    artifact.path,
  ]);
  if (result == null || result.exitCode != 0) return null;
  final output = result.stdout as String;
  // An unsigned file prints a notice and no owner: unreadable, not "fine".
  return output.contains('Owner:') ? output : null;
}

/// Lists the files git tracks in [root] with `git ls-files`. `null` when git
/// is missing or [root] isn't a work tree.
Future<List<String>?> gitTrackedFiles(Directory root) async {
  final result = await _run('git', [
    'ls-files',
    '-z',
  ], workingDirectory: root.path);
  if (result == null || result.exitCode != 0) return null;
  return [
    for (final path in (result.stdout as String).split('\x00'))
      if (path.isNotEmpty) path,
  ];
}

const _env = 'app/env/prod.json';
const _googleServices = 'app/android/app/src/prod/google-services.json';
const _googleServiceInfo = 'app/ios/config/prod/GoogleService-Info.plist';
const _secretsProperties = 'app/android/secrets.properties';
const _secretsXcconfig = 'app/ios/Flutter/Secrets.xcconfig';
const _keyProperties = 'app/android/key.properties';
const _flavor = 'app/lib/app/flavor.dart';
const _appLinks = 'app/lib/app/app_links.dart';
const _intermediates = 'app/build/app/intermediates';
const _aab = 'app/build/app/outputs/bundle/prodRelease/app-prod-release.aab';
const _ipaDir = 'app/build/ios/ipa';

/// Google's test AdMob publisher: its ids serve test ads and earn nothing.
const _testPublisher = '3940256099942544';
const _minTargetSdk = 35;

final _adUnit = RegExp(r'^ca-app-pub-\d{16}/\d{10}$');
final _adMobAppId = RegExp(r'^ca-app-pub-\d{16}~\d{10}$');

/// Runs every check of [stage] for [platform] on the tree at [root] and
/// returns the refusals in the order of the P9-R2 table; empty means pass.
///
/// [ReleaseStage.manifest] runs only the merged-manifest checks;
/// [ReleaseStage.post] runs those and the artifact checks.
Future<List<Refusal>> checkRelease({
  required Directory root,
  required ReleasePlatform platform,
  ReleaseStage stage = ReleaseStage.pre,
  CertificatePrinter printCertificate = keytoolPrintCertificate,
  TrackedFileLister listTrackedFiles = gitTrackedFiles,
}) async {
  final checker = _Checker(root, platform);
  switch (stage) {
    case ReleaseStage.pre:
      await checker.pre(listTrackedFiles);
    case ReleaseStage.manifest:
      checker.manifest(withAdMobId: false);
    case ReleaseStage.post:
      checker.manifest(withAdMobId: true);
      await checker.artifact(printCertificate);
  }
  return checker.refusals;
}

final class _Checker {
  _Checker(this.root, this.platform);

  final Directory root;
  final ReleasePlatform platform;
  final refusals = <Refusal>[];

  bool get android => platform == ReleasePlatform.android;

  File file(String path) => File('${root.path}/$path');

  String? read(String path) {
    final f = file(path);
    try {
      return f.existsSync() ? f.readAsStringSync() : null;
    } on FileSystemException {
      return null;
    }
  }

  void refuse(String code, String message) =>
      refusals.add(Refusal(code, message));

  Future<void> pre(TrackedFileLister listTrackedFiles) async {
    _envChecks();
    final prodId = _prodApplicationId();
    if (android) {
      _firebaseAndroid(prodId);
      _admobAppId(
        'admob-app-android',
        _secretsProperties,
        'admobAppIdProd',
        _properties(read(_secretsProperties)),
      );
      _signing();
    } else {
      _firebaseIos(prodId);
      _admobAppId(
        'admob-app-ios',
        _secretsXcconfig,
        'ADMOB_APP_ID_PROD',
        _xcconfig(read(_secretsXcconfig)),
      );
    }
    await _tracked(listTrackedFiles);
    _links();
  }

  void _envChecks() {
    final text = read(_env);
    Object? decoded;
    if (text != null) {
      try {
        decoded = jsonDecode(text);
      } on FormatException {
        decoded = null;
      }
    }
    if (decoded is! Map<String, Object?>) {
      refuse(
        'env-missing',
        "$_env is missing or isn't a JSON object: copy app/env/example.json "
            'to it and fill in every service key. The other env checks were '
            'skipped.',
      );
      return;
    }
    final env = decoded;
    if (env['FIREBASE_ENABLED'] != true) {
      refuse(
        'firebase-disabled',
        'FIREBASE_ENABLED in $_env must be the JSON boolean true; otherwise '
            'prod ships with no analytics and no crash reports.',
      );
    }
    bool matches(String key, RegExp pattern) {
      final value = env[key];
      return value is String && pattern.hasMatch(value);
    }

    if (!matches('REVENUECAT_ANDROID_KEY', RegExp(r'^goog_[A-Za-z0-9]+$'))) {
      refuse(
        'revenuecat-android',
        'REVENUECAT_ANDROID_KEY in $_env must be the Google Play key of the '
            'RevenueCat project (goog_...), not empty or a Test Store key; '
            'otherwise Premium is never offered on Android.',
      );
    }
    if (!matches('REVENUECAT_IOS_KEY', RegExp(r'^appl_[A-Za-z0-9]+$'))) {
      refuse(
        'revenuecat-ios',
        'REVENUECAT_IOS_KEY in $_env must be the App Store key of the '
            'RevenueCat project (appl_...), not empty or a Test Store key; '
            'otherwise Premium is never offered on iOS.',
      );
    }
    bool realUnit(String key) =>
        matches(key, _adUnit) &&
        !(env[key]! as String).contains(_testPublisher);
    for (final (code, key) in const [
      ('banner-android', 'ADMOB_BANNER_ANDROID'),
      ('banner-ios', 'ADMOB_BANNER_IOS'),
    ]) {
      if (!realUnit(key)) {
        refuse(
          code,
          '$key in $_env must be a real AdMob ad unit id '
          '(ca-app-pub-<16 digits>/<10 digits>), not empty or one of '
          "Google's test units.",
        );
      }
    }
    for (final (code, key) in const [
      ('interstitial-android', 'ADMOB_INTERSTITIAL_ANDROID'),
      ('interstitial-ios', 'ADMOB_INTERSTITIAL_IOS'),
    ]) {
      final value = env[key];
      final empty = value == null || value == '';
      if (!empty && !realUnit(key)) {
        refuse(
          code,
          "$key in $_env is set but isn't a real AdMob ad unit id "
          "(ca-app-pub-<16 digits>/<10 digits>, not Google's test units). "
          'Leave it empty to keep interstitials off.',
        );
      }
    }
    final debug = [
      for (final key in const ['UMP_DEBUG_GEOGRAPHY', 'UMP_TEST_DEVICE_ID'])
        if (env[key] != null && env[key] != '') key,
    ];
    if (debug.isNotEmpty) {
      refuse(
        'ump-debug',
        '${debug.join(' and ')} in $_env must be empty in prod: the consent '
            "debug settings fake the user's region for testing.",
      );
    }
  }

  /// The `applicationId` of `prod` in `flavor.dart`, or `null`.
  String? _prodApplicationId() {
    final text = read(_flavor);
    if (text == null) return null;
    final match = RegExp(
      r"\bprod\s*\([^)]*?applicationId:\s*'([^']+)'",
    ).firstMatch(text);
    return match?.group(1);
  }

  void _firebaseAndroid(String? prodId) {
    const code = 'firebase-android-config';
    if (prodId == null) {
      refuse(code, "Can't read the prod applicationId from $_flavor.");
      return;
    }
    final text = read(_googleServices);
    if (text == null) {
      refuse(
        code,
        '$_googleServices is missing: download it from the Firebase console '
        '(Android app $prodId).',
      );
      return;
    }
    Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      refuse(code, "$_googleServices isn't valid JSON.");
      return;
    }
    final clients = json is Map ? json['client'] : null;
    final names = <Object?>[
      if (clients is List)
        for (final client in clients)
          if (client is Map &&
              client['client_info'] is Map &&
              (client['client_info'] as Map)['android_client_info'] is Map)
            ((client['client_info'] as Map)['android_client_info']
                as Map)['package_name'],
    ];
    if (!names.contains(prodId)) {
      refuse(
        code,
        '$_googleServices has no Android client for $prodId: download the '
        "prod app's file from the Firebase console.",
      );
    }
  }

  void _firebaseIos(String? prodId) {
    const code = 'firebase-ios-config';
    if (prodId == null) {
      refuse(code, "Can't read the prod applicationId from $_flavor.");
      return;
    }
    final text = read(_googleServiceInfo);
    if (text == null) {
      refuse(
        code,
        '$_googleServiceInfo is missing: download it from the Firebase '
        'console (iOS app $prodId).',
      );
      return;
    }
    final bundleId = RegExp(
      r'<key>BUNDLE_ID</key>\s*<string>([^<]+)</string>',
    ).firstMatch(text)?.group(1)?.trim();
    if (bundleId != prodId) {
      refuse(
        code,
        "$_googleServiceInfo's BUNDLE_ID isn't $prodId: download the prod "
        "app's file from the Firebase console.",
      );
    }
  }

  void _admobAppId(
    String code,
    String path,
    String key,
    Map<String, String>? values,
  ) {
    String? problem;
    final value = values?[key];
    if (values == null) {
      final example = path.endsWith('.properties')
          ? 'secrets.example.properties'
          : 'Secrets.example.xcconfig';
      problem = 'is missing (copy $example next to it)';
    } else if (value == null) {
      problem = 'has no $key';
    } else if (value.isEmpty) {
      problem = 'has an empty $key';
    } else if (value.contains('XXXXXXXX')) {
      problem = "still has the example's placeholder $key";
    } else if (value.contains(_testPublisher)) {
      problem = "has Google's test app id as $key";
    } else if (!_adMobAppId.hasMatch(value)) {
      problem =
          "has a $key that isn't an AdMob app id "
          '(ca-app-pub-<16 digits>~<10 digits>)';
    }
    if (problem != null) {
      refuse(
        code,
        '$path $problem: set $key to the real AdMob app id from the AdMob '
        'console.',
      );
    }
  }

  void _signing() {
    const code = 'signing';
    final values = _properties(read(_keyProperties));
    if (values == null) {
      refuse(
        code,
        '$_keyProperties is missing: a prod app bundle must be signed with '
        'the upload key. Copy app/android/key.properties.example to it and '
        'fill it in (store-release skill).',
      );
      return;
    }
    final missing = [
      for (final key in const [
        'storeFile',
        'storePassword',
        'keyAlias',
        'keyPassword',
      ])
        if ((values[key] ?? '').isEmpty) key,
    ];
    if (missing.isNotEmpty) {
      refuse(
        code,
        '$_keyProperties is incomplete: ${missing.join(', ')} missing. See '
        'app/android/key.properties.example.',
      );
      return;
    }
    final storeFile = values['storeFile']!;
    if (!_storeFile(storeFile).existsSync()) {
      refuse(
        code,
        "$_keyProperties points at $storeFile, which doesn't exist. Restore "
        'the upload keystore from your backup, or fix storeFile.',
      );
    }
  }

  /// [path] as Gradle resolves it (P9-R3): `~/` is the home directory, an
  /// absolute path stays, anything else is relative to `app/android/`.
  File _storeFile(String path) {
    if (path.startsWith('~/')) {
      final env = Platform.environment;
      final home = Platform.isWindows
          ? (env['USERPROFILE'] ?? env['HOME'])
          : env['HOME'];
      return File('$home/${path.substring(2)}');
    }
    final f = File(path);
    return f.isAbsolute ? f : file('app/android/$path');
  }

  Future<void> _tracked(TrackedFileLister listTrackedFiles) async {
    const code = 'secrets-tracked';
    List<String>? tracked;
    try {
      tracked = await listTrackedFiles(root);
    } on Object {
      tracked = null;
      // Falls through to the "couldn't list" refusal below.
    }
    if (tracked == null) {
      refuse(
        code,
        "git couldn't list the tracked files in ${root.path}, so the "
        'never-commit check could not run. Run the release from a git '
        'checkout with git on the PATH.',
      );
      return;
    }
    final secrets = tracked.where(_neverCommit).toList();
    if (secrets.isNotEmpty) {
      refuse(
        code,
        'git tracks ${secrets.join(', ')}, which must never be committed: '
        '`git rm --cached` it, and treat what it held as leaked.',
      );
    }
  }

  void _links() {
    final text = read(_appLinks);
    if (text == null) {
      refuse('placeholder-links', '$_appLinks is missing.');
      return;
    }
    if (text.contains('example.com')) {
      final which = [
        if (text.contains('example.com/privacy')) 'privacy policy',
        if (text.contains('example.com/terms')) 'terms',
        if (text.contains('@example.com')) 'support email',
      ];
      refuse(
        'placeholder-links',
        '$_appLinks still has example.com placeholders'
            '${which.isEmpty ? '' : ' (${which.join(', ')})'}: set the real '
            'addresses in AppLinks (docs/release/placeholders.json).',
      );
    }
    if (!android && text.contains('id0000000000')) {
      refuse(
        'app-store-id',
        '$_appLinks still has the placeholder App Store id id0000000000: set '
            "the app's id from App Store Connect.",
      );
    }
  }

  void manifest({required bool withAdMobId}) {
    if (!android) return;
    final manifest = _newestMergedManifest();
    if (manifest == null) {
      refuse(
        'manifest-missing',
        'No merged AndroidManifest.xml under '
            '$_intermediates/merged_manifest*/prodRelease/: build the prodRelease '
            'variant first.',
      );
      return;
    }
    final String text;
    try {
      text = manifest.readAsStringSync();
    } on FileSystemException {
      refuse('manifest-missing', "Can't read ${manifest.path}.");
      return;
    }
    final application =
        RegExp(r'<application\b[^>]*>').firstMatch(text)?.group(0) ?? '';
    final missing = [
      for (final (name, value) in const [
        ('android:allowBackup', 'false'),
        ('android:fullBackupContent', 'false'),
        ('android:dataExtractionRules', '@xml/data_extraction_rules'),
      ])
        if (!RegExp(
          '${RegExp.escape(name)}\\s*=\\s*"${RegExp.escape(value)}"',
        ).hasMatch(application))
          '$name="$value"',
    ];
    if (missing.isNotEmpty) {
      refuse(
        'manifest-backup',
        'The merged manifest ${manifest.path} lacks ${missing.join(', ')} on '
            "<application>: the phone's data would leave it in a backup or "
            'device transfer (decision #49).',
      );
    }
    final usesSdk = RegExp(r'<uses-sdk\b[^>]*>').firstMatch(text)?.group(0);
    final target = int.tryParse(
      RegExp(
            r'android:targetSdkVersion\s*=\s*"(\d+)"',
          ).firstMatch(usesSdk ?? '')?.group(1) ??
          '',
    );
    if (target == null || target < _minTargetSdk) {
      refuse(
        'manifest-target-sdk',
        'The merged manifest targets SDK ${target ?? 'nothing'}; Google Play '
            'needs $_minTargetSdk or later (confirm the current floor in the '
            'Play Console).',
      );
    }
    if (!withAdMobId) return;
    String? adMobId;
    for (final match in RegExp(r'<meta-data\b[^>]*>').allMatches(text)) {
      final element = match.group(0)!;
      if (!element.contains(
        'android:name="com.google.android.gms.ads.APPLICATION_ID"',
      )) {
        continue;
      }
      adMobId = RegExp(
        r'android:value\s*=\s*"([^"]*)"',
      ).firstMatch(element)?.group(1);
    }
    if (adMobId == null || adMobId.contains(_testPublisher)) {
      refuse(
        'manifest-admob-id',
        adMobId == null
            ? 'The merged manifest has no AdMob APPLICATION_ID meta-data.'
            : "The merged manifest uses Google's test AdMob app id: set "
                  'admobAppIdProd in app/android/secrets.properties and '
                  'rebuild.',
      );
    }
  }

  File? _newestMergedManifest() {
    final intermediates = Directory('${root.path}/$_intermediates');
    if (!intermediates.existsSync()) return null;
    File? newest;
    DateTime? newestTime;
    for (final dir in intermediates.listSync().whereType<Directory>()) {
      final name = dir.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (!name.startsWith('merged_manifest')) continue;
      final variant = Directory('${dir.path}/prodRelease');
      if (!variant.existsSync()) continue;
      for (final f in variant.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('AndroidManifest.xml')) continue;
        final time = f.lastModifiedSync();
        if (newestTime == null || time.isAfter(newestTime)) {
          newest = f;
          newestTime = time;
        }
      }
    }
    return newest;
  }

  Future<void> artifact(CertificatePrinter printCertificate) async {
    if (!android) {
      final dir = Directory('${root.path}/$_ipaDir');
      final ipas = dir.existsSync()
          ? dir.listSync().whereType<File>().where(
              (f) => f.path.endsWith('.ipa'),
            )
          : const <File>[];
      if (ipas.isEmpty) {
        refuse(
          'artifact-missing',
          'No .ipa in $_ipaDir/: run flutter build ipa first.',
        );
      }
      return;
    }
    final aab = file(_aab);
    if (!aab.existsSync()) {
      refuse(
        'artifact-missing',
        '$_aab is missing: run flutter build appbundle first.',
      );
      return;
    }
    String? certificate;
    try {
      certificate = await printCertificate(aab);
    } on Object {
      certificate = null;
      // Treated as unreadable below.
    }
    if (certificate == null) {
      refuse(
        'debug-signed',
        "The signature of $_aab couldn't be read (is keytool in "
            'JAVA_HOME/bin or on the PATH?), so it may be unsigned or '
            'debug-signed.',
      );
    } else if (certificate.contains('CN=Android Debug')) {
      refuse(
        'debug-signed',
        '$_aab is signed with the debug key; Google Play only accepts the '
            'upload key. Check app/android/key.properties.',
      );
    }
  }
}

/// Whether [path] (repo-relative) is on the never-commit list of the
/// `store-release` skill.
bool _neverCommit(String path) {
  final name = path.split('/').last;
  const names = {
    'key.properties',
    'google-services.json',
    'GoogleService-Info.plist',
    'secrets.properties',
    'Secrets.xcconfig',
    '.env',
  };
  if (names.contains(name)) return true;
  if (name.endsWith('.jks') ||
      name.endsWith('.keystore') ||
      name.endsWith('.p8')) {
    return true;
  }
  return path.startsWith('app/env/') &&
      path.endsWith('.json') &&
      path != 'app/env/example.json' &&
      !path.substring('app/env/'.length).contains('/');
}

/// `key=value` lines of a `.properties` file, or `null` for no file.
Map<String, String>? _properties(String? text) =>
    _keyValues(text, (line) => line.startsWith('#') || line.startsWith('!'));

/// `KEY = value` lines of an `.xcconfig` file, or `null` for no file.
Map<String, String>? _xcconfig(String? text) =>
    _keyValues(text, (line) => line.startsWith('//') || line.startsWith('#'));

Map<String, String>? _keyValues(
  String? text,
  bool Function(String line) isComment,
) {
  if (text == null) return null;
  final values = <String, String>{};
  for (final raw in const LineSplitter().convert(text)) {
    final line = raw.trim();
    if (line.isEmpty || isComment(line)) continue;
    final eq = line.indexOf('=');
    if (eq <= 0) continue;
    values[line.substring(0, eq).trim()] = line.substring(eq + 1).trim();
  }
  return values;
}

const _usage =
    'Usage: dart tool/release_check.dart --platform android|ios '
    '[--stage pre|manifest|post] [--root <repo>]';

/// Runs the checks the arguments ask for. Exit code 0 pass, 1 refused,
/// 64 bad arguments.
Future<void> main(List<String> args) async {
  ReleasePlatform? platform;
  var stage = ReleaseStage.pre;
  String? rootPath;
  String? error;
  for (var i = 0; i < args.length && error == null; i++) {
    final flag = args[i];
    final value = i + 1 < args.length ? args[i + 1] : null;
    switch (flag) {
      case '--platform' when value != null:
        platform = _named(ReleasePlatform.values, value);
        if (platform == null) error = 'Unknown platform "$value".';
        i++;
      case '--stage' when value != null:
        final s = _named(ReleaseStage.values, value);
        if (s == null) {
          error = 'Unknown stage "$value".';
        } else {
          stage = s;
        }
        i++;
      case '--root' when value != null:
        rootPath = value;
        i++;
      default:
        error = 'Unexpected argument "$flag".';
    }
  }
  if (error == null && platform == null) error = '--platform is required.';
  if (error != null || platform == null) {
    stderr
      ..writeln(error)
      ..writeln(_usage);
    exitCode = 64;
    return;
  }
  final root = rootPath != null
      ? Directory(rootPath).absolute
      : File.fromUri(Platform.script).parent.parent.parent;
  final found = await checkRelease(
    root: root,
    platform: platform,
    stage: stage,
  );
  if (found.isEmpty) {
    stdout.writeln('All ${platform.name} ${stage.name} release checks passed.');
    exitCode = 0;
    return;
  }
  found.forEach(stdout.writeln);
  stdout.writeln('${found.length} problem(s). Fix them before a store build.');
  exitCode = 1;
}

/// The value of [values] called [name], or `null`.
T? _named<T extends Enum>(List<T> values, String name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}
