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
bool _ready(String? shell) {
  if (shell == null) {
    markTestSkipped('bash is not on the PATH');
    return false;
  }
  return requireTool(shell, const ['-c', 'exit 0']) &&
      requireTool('git') &&
      requireTool('dart');
}

/// The tree of someone who has filled in nothing.
Directory _emptyTree() => writeReleaseFixture(
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
      if (!_ready('powershell')) return;
      final root = _emptyTree();
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
      if (!_ready('powershell')) return;
      final root = writeReleaseFixture();
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
    if (!_ready(bash)) return;
    final root = _emptyTree();
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
    if (!_ready(bash)) return;
    final root = writeReleaseFixture();
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
      if (!_ready('powershell')) return;
      final root = writeReleaseFixture();
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
    'wrappers_exit_64_on_bad_arguments',
    () async {
      if (!_ready('powershell')) return;
      final ps1 = await _ps1(['-Platform', 'windows', '-DryRun']);
      expect(ps1.exitCode, 64, reason: '${ps1.stdout}${ps1.stderr}');
      final bash = _bash();
      if (bash == null) return;
      final sh = await _sh(bash, ['--platform', 'windows', '--dry-run']);
      expect(sh.exitCode, 64, reason: '${sh.stdout}${sh.stderr}');
    },
    skip: windowsOnly,
  );
}
