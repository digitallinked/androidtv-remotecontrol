import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ruling P8-R8 / P9-R8: the app branches on `defaultTargetPlatform`, which
/// tests can override, never on `dart:io`'s `Platform`, which reports the
/// host and on Android gives the kernel's version.
///
/// Any member of `Platform` counts (`Platform.version`, `Platform.script`,
/// ...), not a fixed list, and a `show` import may span lines. The `\b`
/// keeps Flutter's `TargetPlatform.iOS` and `defaultTargetPlatform` out.
final _uses = RegExp(r'\bPlatform\.[a-zA-Z_]\w*');
final _imports = RegExp(
  r'''import\s+['"]dart:io['"][^;]*?\bshow\b[^;]*\bPlatform\b''',
);

/// The offending matches in [source], one per match.
List<String> _offences(String source) => [
  for (final pattern in [_uses, _imports])
    for (final match in pattern.allMatches(source)) match.group(0)!,
];

/// Every use of `dart:io`'s `Platform` in `app/lib` (generated files
/// aside), as `<path>: <match>`. Run from `app/`.
List<String> appLibDartIoPlatformOffenders() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
      .toList();
  if (files.isEmpty) throw StateError('no Dart files under lib/');
  return [
    for (final file in files)
      for (final offence in _offences(file.readAsStringSync()))
        '${file.path.replaceAll(r'\', '/')}: $offence',
  ];
}

void main() {
  test('app_lib_never_uses_dart_io_platform', () {
    // The patterns catch what they are for, and leave Flutter's own names
    // alone: a scan that matches nothing proves nothing.
    expect(
      _offences(
        "import 'dart:io' show File, Platform;\n"
        'if (Platform.isAndroid) {}\n'
        'final v = io.Platform.operatingSystemVersion;\n'
        'final e = Platform.environment;\n'
        "import 'dart:io'\n    show\n        File,\n        Platform;\n"
        'final d = Platform.version;\n'
        'final s = io.Platform.script;\n',
      ),
      hasLength(7),
    );
    expect(
      _offences(
        "import 'package:flutter/foundation.dart';\n"
        'if (defaultTargetPlatform == TargetPlatform.iOS) {}\n'
        'final p = Theme.of(context).platform;\n'
        "import 'dart:io' show File;\n"
        'final t = TargetPlatform.android;\n',
      ),
      isEmpty,
    );

    final offenders = appLibDartIoPlatformOffenders();
    expect(
      offenders,
      isEmpty,
      reason:
          'Use defaultTargetPlatform from package:flutter/foundation.dart '
          '(tests: testWidgetsOn), not dart:io Platform (Ruling P9-R8).',
    );
  });
}
