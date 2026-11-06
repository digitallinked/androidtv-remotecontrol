import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/release_fixture.dart';

const String _project = 'ios/Runner.xcodeproj/project.pbxproj';
const String _admobScript = 'ios/scripts/check_admob_app_id.sh';
const String _symbolsScript = 'ios/scripts/upload_crashlytics_symbols.sh';

/// Where CocoaPods writes the Runner target's xcconfigs.
const String _podsDir = 'Pods/Target Support Files/Pods-Runner';

/// Google's test AdMob app id for iOS.
const String _testAppId = 'ca-app-pub-3940256099942544~1458002511';

/// The Runner target's six flavor configurations.
const List<String> _flavorConfigs = [
  'Debug-dev',
  'Debug-prod',
  'Profile-dev',
  'Profile-prod',
  'Release-dev',
  'Release-prod',
];

/// The file's text with \n line endings (the Windows checkout has CRLF).
String _read(String p) => File(p).readAsStringSync().replaceAll('\r\n', '\n');

/// The body of the multi-line object [id] in [pbx], or `null`.
String? _object(String pbx, String id) => RegExp(
  '\\t\\t$id /\\* [^\\n]*? \\*/ = \\{(.*?)\\n\\t\\t\\};',
  dotAll: true,
).firstMatch(pbx)?.group(1);

/// The Runner app target's body.
String _runnerTarget(String pbx) => RegExp(
  r'\t\t\w{24} /\* Runner \*/ = \{\n\t\t\tisa = PBXNativeTarget;(.*?)\n\t\t\};',
  dotAll: true,
).firstMatch(pbx)!.group(1)!;

/// The `(id, name)` entries of a `key = ( … );` list in [body].
List<(String, String)> _list(String body, String key) {
  final list = RegExp(
    '\\t$key = \\((.*?)\\);',
    dotAll: true,
  ).firstMatch(body)!.group(1)!;
  return [
    for (final m in RegExp(
      r'([0-9A-F]{24}) /\* (.+?) \*/,',
    ).allMatches(list))
      (m.group(1)!, m.group(2)!),
  ];
}

/// Runner's build phases, without the `[CP] …` phases that `pod install`
/// adds on a Mac (it puts its manifest check first and its embed step last).
List<(String, String)> _runnerPhases(String pbx) => _list(
  _runnerTarget(pbx),
  'buildPhases',
).where((p) => !p.$2.startsWith('[CP] ')).toList();

/// The quoted strings of the `inputPaths` list of a phase body.
List<String> _inputPaths(String phase) {
  final list = RegExp(
    r'inputPaths = \((.*?)\);',
    dotAll: true,
  ).firstMatch(phase)!.group(1)!;
  return [
    for (final m in RegExp(r'"((?:[^"\\]|\\.)*)",').allMatches(list))
      m.group(1)!,
  ];
}

/// A POSIX `sh`: Git's on Windows (the `bash` on PATH there is often WSL's),
/// otherwise the `sh` on PATH.
String _sh() {
  if (!Platform.isWindows) return 'sh';
  final env = Platform.environment;
  for (final base in [
    env['ProgramFiles'],
    env['ProgramW6432'],
    if (env['LOCALAPPDATA'] != null) '${env['LOCALAPPDATA']}\\Programs',
  ]) {
    if (base == null) continue;
    final candidate = '$base\\Git\\bin\\sh.exe';
    if (File(candidate).existsSync()) return candidate;
  }
  // Git installed elsewhere: whatever `sh` is on PATH.
  return 'sh';
}

/// The `sh` to run the scripts with, or `null` after marking the test
/// skipped (`sh is not on the PATH`).
Future<String?> _requireSh() async {
  final sh = _sh();
  return await requireTool(sh, const ['-c', 'exit 0']) ? sh : null;
}

/// Forward slashes, which both Git's sh and native tools accept.
String _slashed(String path) => path.replaceAll(r'\', '/');

/// A temp directory, deleted after the test.
Directory _tempDir() {
  final dir = Directory.systemTemp.createTempSync('release_fixture_');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

void main() {
  test('admob_check_runs_first_in_the_runner_build', () {
    final pbx = _read(_project);
    final phases = _runnerPhases(pbx);
    expect(phases.first.$2, 'Check AdMob app id');
    // It runs before Flutter's own build script compiles anything.
    expect(phases[1].$2, 'Run Script');

    final phase = _object(pbx, phases.first.$1)!;
    expect(phase, contains('\n\t\t\tisa = PBXShellScriptBuildPhase;'));
    expect(phase, contains('\n\t\t\tname = "Check AdMob app id";'));
    expect(phase, contains('\n\t\t\talwaysOutOfDate = 1;'));
    expect(phase, contains('\n\t\t\tshellPath = /bin/sh;'));
    expect(
      phase,
      contains(
        r'shellScript = "/bin/sh \"$SRCROOT/scripts/check_admob_app_id.sh\"\n";',
      ),
    );
    expect(_inputPaths(phase), isEmpty);
    expect(File(_admobScript).existsSync(), isTrue);
  });

  // The brief's test name, verbatim.
  // ignore: lines_longer_than_80_chars
  test('crashlytics_symbols_upload_runs_last_after_the_firebase_config_copy', () {
    final pbx = _read(_project);
    final phases = _runnerPhases(pbx);
    final names = phases.map((p) => p.$2).toList();
    expect(names.last, 'Upload Crashlytics symbols');
    expect(
      names.indexOf('Copy Firebase config'),
      allOf(isNonNegative, lessThan(names.length - 1)),
    );

    final phase = _object(pbx, phases.last.$1)!;
    expect(phase, contains('\n\t\t\tisa = PBXShellScriptBuildPhase;'));
    expect(phase, contains('\n\t\t\tname = "Upload Crashlytics symbols";'));
    expect(phase, contains('\n\t\t\talwaysOutOfDate = 1;'));
    expect(phase, contains('\n\t\t\tshellPath = /bin/sh;'));
    expect(
      phase,
      contains(
        r'shellScript = "/bin/sh \"$SRCROOT/scripts/upload_crashlytics_symbols.sh\"\n";',
      ),
    );
    // P9-R5's input paths without the GoogleService-Info.plist (P9-C4): no
    // phase declares it as an output, so Xcode would fail every build that
    // lacks it. The script checks for the file itself.
    expect(_inputPaths(phase), [
      r'${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}',
      r'${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${PRODUCT_NAME}',
      r'${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Info.plist',
      r'$(TARGET_BUILD_DIR)/$(EXECUTABLE_PATH)',
    ]);
    expect(File(_symbolsScript).existsSync(), isTrue);
  });

  test('every_configuration_builds_dsyms_for_the_upload_phase_inputs', () {
    // The dSYM input paths must exist in Debug too, or Xcode fails the build
    // before the script can skip it (P9-C4).
    final pbx = _read(_project);
    expect(pbx, isNot(contains('DEBUG_INFORMATION_FORMAT = dwarf;')));
    expect(
      'DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";'.allMatches(pbx),
      hasLength(9),
      reason: 'all nine project-level configurations',
    );
  });

  test('every_shell_phase_is_defined_once_and_used_by_the_runner_target', () {
    final pbx = _read(_project);

    // Every object id is unique.
    final ids = RegExp(
      r'^\t\t([0-9A-F]{24}) ',
      multiLine: true,
    ).allMatches(pbx).map((m) => m.group(1)!).toList();
    expect(ids.toSet().length, ids.length, reason: 'duplicate object ids');

    // Every Runner phase is defined, and every shell phase is in Runner's
    // list exactly once.
    final runner = _list(_runnerTarget(pbx), 'buildPhases');
    for (final (id, name) in runner) {
      expect(_object(pbx, id), isNotNull, reason: '$name is defined');
    }
    final section = RegExp(
      r'/\* Begin PBXShellScriptBuildPhase section \*/(.*?)'
      r'/\* End PBXShellScriptBuildPhase section \*/',
      dotAll: true,
    ).firstMatch(pbx)!.group(1)!;
    final shellIds = RegExp(
      r'^\t\t([0-9A-F]{24}) /\*',
      multiLine: true,
    ).allMatches(section).map((m) => m.group(1)!).toList();
    expect(shellIds, hasLength(greaterThanOrEqualTo(5)));
    // The section is sorted, as Xcode writes it.
    expect(shellIds, [...shellIds]..sort());
    for (final id in shellIds) {
      expect(runner.where((p) => p.$1 == id), hasLength(1), reason: id);
      expect(id.allMatches(pbx), hasLength(2), reason: '$id: def + 1 ref');
    }
  });

  test('the_scripts_parse_as_posix_sh', () async {
    final sh = await _requireSh();
    if (sh == null) return;
    for (final script in [_admobScript, _symbolsScript]) {
      final result = await runTool(sh, ['-n', script]);
      expect(result.exitCode, 0, reason: '$script: ${result.stderr}');
      final text = _read(script);
      expect(text, startsWith('#!/bin/sh\n'));
      expect(text, contains('\nset -eu\n'));
    }
  });

  test('admob_check_script_behaviour', () async {
    final sh = await _requireSh();
    if (sh == null) return;
    const cases = <(String, String, String, int, String?)>[
      ('Debug-dev', 'build', '', 0, null),
      ('Release-dev', 'install', _testAppId, 0, null),
      ('Release-prod', 'build', _testAppId, 0, 'warning:'),
      ('Release-prod', 'install', _testAppId, 1, 'error:'),
      ('Debug-prod', 'build', '', 1, 'error:'),
      (
        'Release-prod',
        'build',
        'ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY',
        1,
        'error:',
      ),
      (
        'Release-prod',
        'install',
        'ca-app-pub-1234567890123456/1234567890',
        1,
        'error:',
      ),
      (
        'Profile-prod',
        'build',
        'ca-app-pub-12345678901234~1234567890',
        1,
        'error:',
      ),
      (
        'Release-prod',
        'install',
        'ca-app-pub-1234567890123456~1234567890',
        0,
        null,
      ),
    ];
    for (final (config, action, id, exit, prefix) in cases) {
      final result = await runTool(
        sh,
        [_admobScript],
        environment: {
          'CONFIGURATION': config,
          'ACTION': action,
          'ADMOB_APP_ID': id,
        },
      );
      final out = '${result.stdout}${result.stderr}';
      final what = '($config, $action, "$id"): $out';
      expect(result.exitCode, exit, reason: what);
      if (prefix == null) {
        expect(out, isNot(contains('error:')), reason: what);
        expect(out, isNot(contains('warning:')), reason: what);
      } else {
        expect(result.stdout as String, contains(prefix), reason: what);
      }
      if (exit == 1) {
        expect(out, contains('ios/Flutter/Secrets.xcconfig'), reason: what);
      }
    }
  });

  test(
    'admob_check_warns_with_the_ruling_text_and_never_prints_the_id',
    () async {
      final sh = await _requireSh();
      if (sh == null) return;
      final warn = await runTool(
        sh,
        [_admobScript],
        environment: {
          'CONFIGURATION': 'Debug-prod',
          'ACTION': 'build',
          'ADMOB_APP_ID': _testAppId,
        },
      );
      expect(
        (warn.stdout as String).trim(),
        "warning: prod uses Google's test AdMob app id; set ADMOB_APP_ID_PROD "
        'in ios/Flutter/Secrets.xcconfig',
      );
      const badId = 'ca-app-pub-1234567890123456/1234567890';
      final bad = await runTool(
        sh,
        [_admobScript],
        environment: {
          'CONFIGURATION': 'Release-prod',
          'ACTION': 'install',
          'ADMOB_APP_ID': badId,
        },
      );
      expect('${bad.stdout}${bad.stderr}', isNot(contains(badId)));
    },
  );

  test(
    'crashlytics_script_skips_without_config_and_runs_the_pods_tool_with_it',
    () async {
      final sh = await _requireSh();
      if (sh == null) return;
      final t = _SymbolsFixture(sh, _tempDir())..writeStub(_SymbolsTool.pods);

      t.plist.writeAsStringSync('<plist/>');
      var result = await t.run('Debug-prod', podsRoot: true);
      expect(result.exitCode, 0, reason: t.output(result));
      expect(result.stdout as String, contains('note:'));
      expect(t.args.existsSync(), isFalse, reason: 'Debug never uploads');

      t.plist.deleteSync();
      result = await t.run('Release-prod', podsRoot: true);
      expect(result.exitCode, 0, reason: t.output(result));
      expect(
        result.stdout as String,
        contains('note: no Firebase config; no symbols uploaded'),
      );
      expect(t.args.existsSync(), isFalse, reason: 'no plist, no upload');

      t.plist.writeAsStringSync('<plist/>');
      result = await t.run('Release-prod', podsRoot: true);
      expect(result.exitCode, 0, reason: t.output(result));
      expect(t.args.readAsStringSync().trim(), 'pods -gsp ${t.plistPath}');
      expect(
        result.stdout as String,
        contains('note: uploading dSYMs with ${t.toolPath(_SymbolsTool.pods)}'),
      );

      t.args.deleteSync();
      t.deleteStub(_SymbolsTool.pods);
      result = await t.run('Release-prod', podsRoot: true);
      expect(result.exitCode, 0, reason: t.output(result));
      expect(result.stdout as String, contains('warning:'));
      expect(result.stdout as String, isNot(contains('pod install')));
      expect(t.args.existsSync(), isFalse);
    },
  );

  test('crashlytics_script_finds_the_swift_package_tool_too', () async {
    final sh = await _requireSh();
    if (sh == null) return;
    final t = _SymbolsFixture(sh, _tempDir());
    t.plist.writeAsStringSync('<plist/>');

    // An archive (flutter build ipa): BUILD_DIR is under DerivedData.
    t.writeStub(_SymbolsTool.spm);
    var result = await t.run('Release-prod', podsRoot: true, buildDir: true);
    expect(result.exitCode, 0, reason: t.output(result));
    expect(t.args.readAsStringSync().trim(), 'spm -gsp ${t.plistPath}');
    expect(
      result.stdout as String,
      contains('note: uploading dSYMs with ${t.toolPath(_SymbolsTool.spm)}'),
    );

    // flutter build ios: BUILD_DIR is build/ios, so OBJROOT finds it.
    t.args.deleteSync();
    result = await t.run('Release-prod', objRoot: true, flutterBuildDir: true);
    expect(result.exitCode, 0, reason: t.output(result));
    expect(t.args.readAsStringSync().trim(), 'spm -gsp ${t.plistPath}');

    // Both: the Pods copy wins.
    t
      ..args.deleteSync()
      ..writeStub(_SymbolsTool.pods);
    result = await t.run(
      'Release-prod',
      podsRoot: true,
      buildDir: true,
      objRoot: true,
    );
    expect(result.exitCode, 0, reason: t.output(result));
    expect(t.args.readAsStringSync().trim(), 'pods -gsp ${t.plistPath}');

    // Neither: a warning, and the build goes on.
    t
      ..args.deleteSync()
      ..deleteStub(_SymbolsTool.pods)
      ..deleteStub(_SymbolsTool.spm);
    result = await t.run(
      'Release-prod',
      podsRoot: true,
      buildDir: true,
      objRoot: true,
    );
    expect(result.exitCode, 0, reason: t.output(result));
    expect(result.stdout as String, contains('warning:'));
    expect(t.args.existsSync(), isFalse);

    // PODS_ROOT, BUILD_DIR and OBJROOT unset: still safe under set -u, and
    // an empty PODS_ROOT never becomes /FirebaseCrashlytics/run.
    t.writeStub(_SymbolsTool.spm);
    result = await t.run('Release-prod');
    expect(result.exitCode, 0, reason: t.output(result));
    expect(t.output(result), isNot(contains('unbound')));
    expect(result.stdout as String, contains('warning:'));
    expect(t.args.existsSync(), isFalse);
  });

  test(
    // The brief's test name, verbatim.
    // ignore: lines_longer_than_80_chars
    'podfile_targets_ios_15_maps_every_configuration_and_drops_the_ad_id_from_analytics',
    () {
      final podfile = _read('ios/Podfile');
      final lines = podfile.split('\n');
      expect(lines, contains("platform :ios, '15.0'"));
      expect(podfile, isNot(contains('# platform :ios')));

      final adIdFlag = lines.indexOf(
        r'$FirebaseAnalyticsWithoutAdIdSupport = true',
      );
      final target = lines.indexOf("target 'Runner' do");
      expect(adIdFlag, isNonNegative);
      expect(target, greaterThan(adIdFlag));

      final map = RegExp(
        r"^project 'Runner', \{\n(.*?)\n\}$",
        dotAll: true,
        multiLine: true,
      ).firstMatch(podfile)!.group(1)!;
      final entries = {
        for (final m in RegExp(
          r"^  '([^']+)' => :(debug|release),$",
          multiLine: true,
        ).allMatches(map))
          m.group(1)!: m.group(2)!,
      };
      expect(entries.keys.toSet(), {
        'Debug',
        'Profile',
        'Release',
        ..._flavorConfigs,
      });
      for (final MapEntry(:key, :value) in entries.entries) {
        expect(
          value,
          key.startsWith('Debug') ? 'debug' : 'release',
          reason: key,
        );
      }

      expect(
        podfile,
        contains(
          'flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))',
        ),
      );
      expect(
        podfile,
        contains('flutter_additional_ios_build_settings(target)'),
      );
      expect(podfile, contains('flutter_ios_podfile_setup'));
      expect(podfile, contains("ENV['COCOAPODS_DISABLE_STATS'] = 'true'"));
    },
  );

  test(
    // The brief's test name, verbatim.
    // ignore: lines_longer_than_80_chars
    'every_runner_flavor_configuration_includes_its_pods_xcconfig_then_the_shared_one',
    () {
      final pbx = _read(_project);
      final listId = RegExp(
        r'\tbuildConfigurationList = ([0-9A-F]{24}) ',
      ).firstMatch(_runnerTarget(pbx))!.group(1)!;
      final list = _list(_object(pbx, listId)!, 'buildConfigurations');
      expect(list.map((c) => c.$2).toSet(), {
        'Debug',
        'Release',
        'Profile',
        ..._flavorConfigs,
      });
      final flutterGroup = RegExp(
        r'/\* Flutter \*/ = \{\n\t\t\tisa = PBXGroup;(.*?)\n\t\t\};',
        dotAll: true,
      ).firstMatch(pbx)!.group(1)!;

      for (final (id, name) in list) {
        final body = _object(pbx, id)!;
        final base = RegExp(
          r'\n\t\t\tbaseConfigurationReference = ([0-9A-F]{24}) /\* (.+?) \*/;',
        ).firstMatch(body);
        expect(base, isNotNull, reason: name);
        final (fileId, fileName) = (base!.group(1)!, base.group(2)!);
        if (!_flavorConfigs.contains(name)) {
          // The plain configurations keep Flutter's own files.
          expect(
            fileName,
            name == 'Debug' ? 'Debug.xcconfig' : 'Release.xcconfig',
          );
          continue;
        }
        expect(fileName, '$name.xcconfig');
        final ref = RegExp(
          '\\t\\t$fileId /\\* $name\\.xcconfig \\*/ = \\{isa = PBXFileReference; '
          'lastKnownFileType = text.xcconfig; name = "$name.xcconfig"; '
          'path = "Flutter/$name.xcconfig"; sourceTree = "<group>"; \\};',
        );
        expect(ref.hasMatch(pbx), isTrue, reason: '$name file reference');
        expect(
          flutterGroup,
          contains('\t\t\t\t$fileId /* $name.xcconfig */,'),
          reason: '$name in the Flutter group',
        );

        final includes = _read(
          'ios/Flutter/$name.xcconfig',
        ).split('\n').where((l) => l.startsWith('#include')).toList();
        final shared = name.startsWith('Debug') ? 'Debug' : 'Release';
        expect(includes, [
          '#include? "$_podsDir/Pods-Runner.${name.toLowerCase()}.xcconfig"',
          '#include "$shared.xcconfig"',
        ], reason: name);
      }
    },
  );

  test('the_scripts_have_lf_line_endings', () {
    for (final script in [_admobScript, _symbolsScript]) {
      expect(
        File(script).readAsBytesSync(),
        isNot(contains(13)),
        reason: script,
      );
    }
  });
}

/// Where a fake FirebaseCrashlytics `run` lives.
enum _SymbolsTool {
  /// `$PODS_ROOT/FirebaseCrashlytics/run`.
  pods('Pods/FirebaseCrashlytics/run'),

  /// The Swift package checkout under DerivedData.
  spm('dd/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run');

  const _SymbolsTool(this.path);

  /// The path under the fixture root.
  final String path;
}

/// A temp tree for `upload_crashlytics_symbols.sh`: a built app bundle, and
/// stub `run` tools that write `<tool> <args>` to [args].
class _SymbolsFixture {
  _SymbolsFixture(this.sh, this.root) {
    Directory('${root.path}/products/Runner.app').createSync(recursive: true);
  }

  /// The shell that runs the script.
  final String sh;

  /// The fixture root.
  final Directory root;

  /// The Firebase config inside the built app.
  File get plist => File(
    '${root.path}/products/Runner.app/'
    'GoogleService-Info.plist',
  );

  /// [plist] as the script sees it.
  String get plistPath => _slashed(plist.path);

  /// Where the stubs write their arguments.
  File get args => File('${root.path}/args.txt');

  /// [tool]'s path as the script sees it.
  String toolPath(_SymbolsTool tool) => _slashed('${root.path}/${tool.path}');

  /// Writes the stub for [tool].
  void writeStub(_SymbolsTool tool) {
    final file = File('${root.path}/${tool.path}')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(
        '#!/bin/sh\nprintf \'%s \' ${tool.name} "\$@" > "\$STUB_OUT"\n',
      );
    if (!Platform.isWindows) Process.runSync('chmod', ['+x', file.path]);
  }

  /// Deletes the stub for [tool].
  void deleteStub(_SymbolsTool tool) =>
      File('${root.path}/${tool.path}').deleteSync();

  /// Runs the script for [config], setting only the variables asked for.
  Future<ProcessResult> run(
    String config, {
    bool podsRoot = false,
    bool buildDir = false,
    bool objRoot = false,
    bool flutterBuildDir = false,
  }) => runTool(
    sh,
    [_symbolsScript],
    environment: {
      'CONFIGURATION': config,
      'BUILT_PRODUCTS_DIR': _slashed('${root.path}/products'),
      'PRODUCT_NAME': 'Runner',
      'STUB_OUT': _slashed(args.path),
      if (podsRoot) 'PODS_ROOT': _slashed('${root.path}/Pods'),
      if (buildDir) 'BUILD_DIR': _slashed('${root.path}/dd/Build/Products'),
      if (flutterBuildDir) 'BUILD_DIR': _slashed('${root.path}/app/build/ios'),
      if (objRoot)
        'OBJROOT': _slashed('${root.path}/dd/Build/Intermediates.noindex'),
    },
  );

  /// stdout and stderr together, for failure messages.
  String output(ProcessResult result) => '${result.stdout}${result.stderr}';
}
