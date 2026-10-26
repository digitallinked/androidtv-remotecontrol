import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every_string_has_a_description', () {
    final arb =
        jsonDecode(File('lib/app/l10n/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    final keys = arb.keys.where((k) => !k.startsWith('@'));
    expect(keys, isNotEmpty);
    for (final key in keys) {
      final meta = arb['@$key'];
      expect(meta, isA<Map<String, dynamic>>(), reason: 'missing @$key');
      final description = (meta as Map<String, dynamic>)['description'];
      expect(
        description,
        isA<String>().having((d) => d.trim(), 'trimmed', isNotEmpty),
        reason: '@$key has no description',
      );
    }
  });
}
