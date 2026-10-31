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

  // A translator sees only the description: a full sentence that says where
  // the string shows ("Section header." doesn't).
  test('every_description_is_a_sentence', () {
    final arb =
        jsonDecode(File('lib/app/l10n/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    final terse = <String>[];
    for (final MapEntry(:key, :value) in arb.entries) {
      if (!key.startsWith('@') || key.startsWith('@@')) continue;
      final description =
          ((value as Map<String, dynamic>)['description'] as String? ?? '')
              .trim();
      final words = description.split(RegExp(r'\s+')).where((w) => w != '');
      if (words.length < 4 || !description.endsWith('.')) {
        terse.add('$key: "$description"');
      }
    }
    expect(terse, isEmpty, reason: terse.join('\n'));
  });
}
