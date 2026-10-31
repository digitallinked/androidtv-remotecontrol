import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ruling P8-R8 / P9-R8: the app branches on `defaultTargetPlatform`, which
/// tests can override, never on `dart:io`'s `Platform`, which reports the
/// host and on Android gives the kernel's version.
final _uses = RegExp(
  r'\bPlatform\.(is[A-Z]\w*|operatingSystem\w*|environment|localeName|'
  r'numberOfProcessors|resolvedExecutable|pathSeparator)\b',
);
final _imports = RegExp(r"import 'dart:io' show[^;]*\bPlatform\b");

/// The offending matches in [source], one per match.
List<String> _offences(String source) => [
  for (final pattern in [_uses, _imports])
    for (final match in pattern.allMatches(source)) match.group(0)!,
];

void main() {
  test('app_lib_never_uses_dart_io_platform', () {
    // The patterns catch what they are for, and leave Flutter's own names
    // alone: a scan that matches nothing proves nothing.
    expect(
      _offences(
        "import 'dart:io' show File, Platform;\n"
        'if (Platform.isAndroid) {}\n'
        'final v = io.Platform.operatingSystemVersion;\n'
        'final e = Platform.environment;\n',
      ),
      hasLength(4),
    );
    expect(
      _offences(
        "import 'package:flutter/foundation.dart';\n"
        'if (defaultTargetPlatform == TargetPlatform.iOS) {}\n'
        'final p = Theme.of(context).platform;\n',
      ),
      isEmpty,
    );

    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
        .toList();
    expect(files, isNotEmpty);

    final offenders = <String>[
      for (final file in files)
        for (final offence in _offences(file.readAsStringSync()))
          '${file.path.replaceAll(r'\', '/')}: $offence',
    ];
    expect(
      offenders,
      isEmpty,
      reason:
          'Use defaultTargetPlatform from package:flutter/foundation.dart '
          '(tests: testWidgetsOn), not dart:io Platform (Ruling P9-R8).',
    );
  });
}
