import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The last key of the first half of `app_en.arb` (Task 8.12); Task 8.13
/// translates the rest.
const String _lastFirstHalfKey = 'addAppCustom';

Map<String, dynamic> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// The message keys of [arb], in file order (no `@` metadata).
List<String> _messages(Map<String, dynamic> arb) => [
  for (final key in arb.keys)
    if (!key.startsWith('@')) key,
];

/// The `{name}` placeholders of [message]. Plural and select messages
/// (`{count, plural, …}`) name theirs before the first comma.
Set<String> _placeholders(String message) => {
  for (final m in RegExp(r'\{(\w+)[,}]').allMatches(message)) m.group(1)!,
};

void main() {
  final en = _read('lib/app/l10n/app_en.arb');
  final ms = _read('lib/app/l10n/app_ms.arb');

  test('ms_translates_the_first_half', () {
    final keys = _messages(en);
    final last = keys.indexOf(_lastFirstHalfKey);
    expect(last, greaterThan(0), reason: '$_lastFirstHalfKey is an en key');
    final missing = <String>[
      for (final key in keys.take(last + 1))
        if (ms[key] is! String || (ms[key] as String).trim().isEmpty) key,
    ];
    expect(missing, isEmpty, reason: 'untranslated: ${missing.join(', ')}');
  });

  test('ms_keeps_every_placeholder', () {
    final drift = <String>[];
    for (final key in _messages(ms)) {
      if (en[key] is! String) continue;
      final mine = _placeholders(ms[key] as String);
      final theirs = _placeholders(en[key] as String);
      if (!_sameSet(mine, theirs)) drift.add('$key: ms $mine vs en $theirs');
    }
    expect(drift, isEmpty, reason: drift.join('\n'));
  });

  test('ms_has_no_metadata_drift', () {
    expect(ms['@@locale'], 'ms');
    final enKeys = _messages(en).toSet();
    final extra = [
      for (final key in _messages(ms))
        if (!enKeys.contains(key)) key,
    ];
    expect(extra, isEmpty, reason: 'keys that are not en keys');
    // Metadata lives in the template; a Malay `@key` may only carry the
    // placeholders gen-l10n needs, for a key that exists.
    final metadata = ms.keys.where((k) => k.startsWith('@') && k != '@@locale');
    for (final key in metadata) {
      final message = key.substring(1);
      expect(enKeys, contains(message), reason: '$key has no en key');
      expect(
        (ms[key] as Map<String, dynamic>).keys,
        everyElement('placeholders'),
        reason: '$key carries only placeholders',
      );
    }
  });
}

bool _sameSet(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);
