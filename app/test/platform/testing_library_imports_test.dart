import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The fake TV is a test-only library (Ruling P8-R3): app code never reaches
/// it, so release builds never contain it.
void main() {
  test('app_lib_never_imports_the_testing_library', () {
    // The barrel, or its implementation files directly.
    const forbidden = [
      'package:atv_remote/testing.dart',
      'package:atv_remote/src/testing/',
    ];
    final offenders = [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          for (final uri in forbidden)
            if (file.readAsStringSync().contains(uri))
              '${file.path.replaceAll(r'\', '/')}: $uri',
    ];
    expect(offenders, isEmpty);
  });

  test('the_main_barrel_does_not_export_the_fake_tv', () {
    final barrel = File(
      '../packages/atv_remote/lib/atv_remote.dart',
    ).readAsStringSync();
    final exports = RegExp(
      r'''^\s*export\s+['"]([^'"]+)['"]''',
      multiLine: true,
    ).allMatches(barrel).map((m) => m.group(1)!).toList();
    expect(exports, isNotEmpty);
    expect(exports.where((uri) => uri.contains('testing')), isEmpty);
    expect(barrel, isNot(contains('FakeTvServer')));
  });
}
