import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'release_fixture.dart';

/// Git Bash on Windows (the `bash` on PATH there is often WSL's, which can't
/// run a Windows Flutter), `bash` elsewhere. `null` when there is none.
String? _bash() {
  if (!Platform.isWindows) return 'bash';
  final env = Platform.environment;
  for (final base in [
    env['ProgramFiles'],
    env['ProgramW6432'],
    if (env['LOCALAPPDATA'] != null) '${env['LOCALAPPDATA']}\\Programs',
  ]) {
    if (base == null) continue;
    final candidate = '$base\\Git\\bin\\bash.exe';
    if (File(candidate).existsSync()) return candidate;
  }
  return null;
}

/// Whether the wrapper test can run: [shell] and git are present, and dart
/// too, which the wrappers call.
Future<bool> _ready(String? shell) async {
  if (shell == null) {
    markTestSkipped('bash is not on the PATH');
    return false;
  }
  return await requireTool(shell, const ['-c', 'exit 0']) &&
      await requireTool('git') &&
      await requireTool('dart');
}

/// The tree of someone who has filled in nothing.
Future<Directory> _emptyTree() => writeReleaseFixture(
  omit: everyConfigFile,
  files: {FixturePaths.appLinks: placeholderAppLinks},
);

Future<ProcessResult> _ps1(List<String> args) => runTool('powershell', [
  '-NoProfile',
  '-NonInteractive',
  '-File',
  '../tool/release.ps1',
  ...args,
]);

Future<ProcessResult> _sh(String bash, List<String> args) =>
    runTool(bash, ['../tool/release.sh', ...args]);

/// Forward slashes, which both Git Bash and native tools accept.
String _slashed(Directory dir) => dir.path.replaceAll(r'\', '/');

int _refusedLines(ProcessResult result) => (result.stdout as String)
    .split(RegExp(r'\r?\n'))
    .where((l) => l.startsWith('REFUSED ['))
    .length;

void main() {
  final onWindows = Platform.isWindows;
  final windowsOnly = onWindows ? null : 'PowerShell 5.1 runs on Windows only';

  test(
    'ps1_dry_run_refuses_an_empty_tree_and_builds_nothing',
    () async {
      if (!await _ready('powershell')) return;
      final root = await _emptyTree();
      final result = await _ps1([
        '-Platform',
        'android',
        '-DryRun',
        '-Root',
        root.path,
      ]);
      expect(_refusedLines(result), 5, reason: '${result.stdout}');
      expect(result.stdout, contains('No build was made.'));
      expect(result.exitCode, 1);
      expect(Directory('${root.path}/app/build').existsSync(), isFalse);
    },
    skip: windowsOnly,
  );

  test(
    'ps1_dry_run_on_a_complete_tree_says_no_build_was_made',
    () async {
      if (!await _ready('powershell')) return;
      final root = await writeReleaseFixture();
      final result = await _ps1([
        '-Platform',
        'android',
        '-DryRun',
        '-Root',
        root.path,
      ]);
      expect(
        result.stdout,
        contains('Dry run: every pre-build check passed. No build was made.'),
      );
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(Directory('${root.path}/app/build').existsSync(), isFalse);
    },
    skip: windowsOnly,
  );

  test('sh_dry_run_refuses_an_empty_tree_and_builds_nothing', () async {
    final bash = _bash();
    if (!await _ready(bash)) return;
    final root = await _emptyTree();
    final result = await _sh(bash!, [
      '--platform',
      'ios',
      '--dry-run',
      '--root',
      _slashed(root),
    ]);
    expect(_refusedLines(result), 5, reason: '${result.stdout}');
    expect(result.stdout, contains('No build was made.'));
    expect(result.exitCode, 1);
    expect(Directory('${root.path}/app/build').existsSync(), isFalse);
  });

  test('sh_dry_run_on_a_complete_tree_says_no_build_was_made', () async {
    final bash = _bash();
    if (!await _ready(bash)) return;
    final root = await writeReleaseFixture();
    final result = await _sh(bash!, [
      '--platform',
      'ios',
      '--dry-run',
      '--root',
      _slashed(root),
    ]);
    expect(
      result.stdout,
      contains('Dry run: every pre-build check passed. No build was made.'),
    );
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(Directory('${root.path}/app/build').existsSync(), isFalse);
  });

  test(
    'ps1_refuses_an_ios_build_off_a_mac',
    () async {
      if (!await _ready('powershell')) return;
      final root = await writeReleaseFixture();
      final result = await _ps1(['-Platform', 'ios', '-Root', root.path]);
      expect(
        result.stdout,
        contains('iOS store builds need a Mac (flutter build ipa).'),
      );
      expect(result.exitCode, 1);
      expect(Directory('${root.path}/app/build').existsSync(), isFalse);
    },
    skip: windowsOnly,
  );

  test(
    'ps1_exits_64_on_bad_arguments',
    () async {
      if (!await _ready('powershell')) return;
      for (final args in const [
        ['-Platform', 'windows', '-DryRun'],
        ['-DryRun'],
      ]) {
        final ps1 = await _ps1(args);
        expect(ps1.exitCode, 64, reason: '$args ${ps1.stdout}${ps1.stderr}');
        expect(ps1.stderr, contains('Usage'), reason: '$args');
      }
    },
    skip: windowsOnly,
  );

  test('sh_ios_build_resolves_analytics_without_the_ad_id', () async {
    final bash = _bash();
    if (!await _ready(bash)) return;
    final root = await writeReleaseFixture();
    // A fake `uname` that claims a Mac, and a fake `flutter` that reports
    // what it was given and fails, so nothing is built (Ruling P9-C4).
    final bin = Directory('${root.path}/fake_bin')..createSync();
    File('${bin.path}/uname').writeAsStringSync('#!/bin/sh\necho Darwin\n');
    File('${bin.path}/flutter').writeAsStringSync(
      '#!/bin/sh\n'
      r'echo "flutter $*"'
      '\n'
      r'v="${FIREBASE_ANALYTICS_WITHOUT_ADID:-unset}"'
      '\n'
      r'echo "FIREBASE_ANALYTICS_WITHOUT_ADID=$v"'
      '\nexit 3\n',
    );
    if (!onWindows) {
      Process.runSync('chmod', [
        '+x',
        '${bin.path}/uname',
        '${bin.path}/flutter',
      ]);
    }
    final separator = onWindows ? ';' : ':';
    // Windows names it `Path`; reuse the parent's spelling so the child
    // doesn't get two entries.
    final pathKey = Platform.environment.keys.firstWhere(
      (k) => k.toUpperCase() == 'PATH',
      orElse: () => 'PATH',
    );
    // Git's bin\bash.exe is a launcher that puts /usr/bin first on PATH,
    // which would hide the fakes; its usr\bin\bash.exe keeps PATH as given.
    final shell = bash!.replaceFirst(
      r'\Git\bin\bash.exe',
      r'\Git\usr\bin\bash.exe',
    );
    // The child's PATH is built here, not inherited as is: the fakes first,
    // then the coreutils next to that bash (dirname, rm, ls), then the
    // parent's PATH for dart. A PowerShell parent has no Git usr\bin on its
    // PATH, so without the middle entry the script can't find `dirname`.
    final result = await runTool(
      shell,
      ['../tool/release.sh', '--platform', 'ios', '--root', _slashed(root)],
      environment: {
        pathKey: [
          bin.path,
          if (onWindows) File(shell).parent.path,
          Platform.environment[pathKey] ?? '',
        ].join(separator),
        // So the fake shows the script's own export, not one inherited.
        'FIREBASE_ANALYTICS_WITHOUT_ADID': '',
      },
    );
    final out = '${result.stdout}${result.stderr}';
    expect(out, contains('flutter build ipa --flavor prod'), reason: out);
    expect(out, contains('FIREBASE_ANALYTICS_WITHOUT_ADID=true'), reason: out);
    expect(out, contains('flutter build ipa failed (exit 3).'), reason: out);
    expect(result.exitCode, 1);
  });

  test('sh_exits_64_on_bad_arguments', () async {
    final bash = _bash();
    if (!await _ready(bash)) return;
    for (final args in const [
      ['--platform', 'windows', '--dry-run'],
      ['--dry-run'],
      ['--platform'],
      ['--bogus'],
    ]) {
      final sh = await _sh(bash!, args);
      expect(sh.exitCode, 64, reason: '$args ${sh.stdout}${sh.stderr}');
      expect(sh.stderr, contains('Usage'), reason: '$args');
    }
  });
}
