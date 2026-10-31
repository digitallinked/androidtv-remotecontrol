import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Malay values that are the English value on purpose: each is made only of
/// names and symbols that stay untranslated (Ruling P8-R8), so it reads the
/// same in both languages.
const Set<String> _sameInBothLanguages = {
  // An example address and a MAC address pattern.
  'manualIpHint',
  'wolMacHint',
  // An example app ID (an Android package name).
  'shortcutPackageHint',
  // Key and control names printed on TV remotes.
  'remotePadDpad',
  'keyOk',
  'keyEnter',
  'volumeLabel',
  'channelLabel',
  // "Menu" is the Malay word too.
  'keyMenu',
  // Only the volume number.
  'remoteVolumeValue',
  // Product names: Premium, the Smooth Press feature and the Premium
  // colour styles.
  'pageTitlePaywall',
  'behaviourSmoothPress',
  'appearanceStyleOcean',
  'appearanceStyleEmber',
  'appearanceStyleMidnight',
};

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

  test('every_key_exists_in_both_arbs', () {
    final enKeys = _messages(en).toSet();
    final msKeys = _messages(ms).toSet();
    final missing = [
      for (final key in _messages(en))
        if (!msKeys.contains(key)) key,
    ];
    final extra = [
      for (final key in _messages(ms))
        if (!enKeys.contains(key)) key,
    ];
    expect(
      [...missing, ...extra],
      isEmpty,
      reason:
          'missing in ms (${missing.length}): ${missing.join(', ')}\n'
          'not in en (${extra.length}): ${extra.join(', ')}',
    );
    final empty = [
      for (final key in msKeys)
        if (ms[key] is! String || (ms[key] as String).trim().isEmpty) key,
    ];
    expect(empty, isEmpty, reason: 'empty ms values: ${empty.join(', ')}');
  });

  test('ms_has_no_english_copies', () {
    final copies = [
      for (final key in _messages(ms))
        if (ms[key] == en[key] && !_sameInBothLanguages.contains(key)) key,
    ];
    expect(copies, isEmpty, reason: 'still English: ${copies.join(', ')}');
    // The allowlist stays exact: every entry is a key whose value really is
    // the same in both languages.
    final stale = [
      for (final key in _sameInBothLanguages)
        if (ms[key] != en[key]) key,
    ];
    expect(stale, isEmpty, reason: 'allowlisted but translated: $stale');
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
