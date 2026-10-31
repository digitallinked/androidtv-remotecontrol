import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'store_copy.dart';

/// The two store-listing languages.
const List<String> locales = ['en', 'ms'];

/// The first line of `ms.md` (Ruling P9-R13).
const String malayStatusLine =
    "Status: UNREVIEWED — needs the owner's sign-off (DM-068) before use.";

/// The P9-R13 field ids and their store limits.
final Map<String, int> p9r13Fields = {
  'play.title': 30,
  'play.short_description': 80,
  'play.full_description': 4000,
  'appstore.name': 30,
  'appstore.subtitle': 30,
  'appstore.promotional_text': 170,
  'appstore.description': 4000,
  'appstore.keywords': 100,
  'release_notes': 500,
  for (var i = 1; i <= 8; i++) 'shot.phone.${'$i'.padLeft(2, '0')}': 40,
  for (var i = 1; i <= 2; i++) 'shot.tablet.${'$i'.padLeft(2, '0')}': 40,
  'feature_graphic.title': 20,
  'feature_graphic.tagline': 40,
};

/// The fields that may carry no third-party trademark (P9-R13).
bool isTrademarkFree(String id) =>
    id == 'play.title' ||
    id == 'appstore.name' ||
    id == 'appstore.subtitle' ||
    id == 'appstore.keywords' ||
    id.startsWith('shot.') ||
    id.startsWith('feature_graphic.');

/// Third-party trademarks the trademark-free fields never carry.
final RegExp trademarks = RegExp(
  'google|android|netflix|youtube|disney|prime video|spotify|apple tv|hbo|'
  'viu|iqiyi|chromecast|roku|fire tv|samsung',
  caseSensitive: false,
);

/// The `aboutTrademark` ARB string for [locale].
String aboutTrademark(String locale) {
  final arb =
      jsonDecode(File('lib/app/l10n/app_$locale.arb').readAsStringSync())
          as Map<String, Object?>;
  return arb['aboutTrademark']! as String;
}

void main() {
  late final values = placeholderValues();
  late final appName = values['APP_NAME']!;

  test('both_languages_have_exactly_the_p9_r13_fields', () {
    for (final locale in locales) {
      final copy = loadStoreCopy(locale);
      expect(copy.keys.toSet(), p9r13Fields.keys.toSet(), reason: locale);
      for (final field in copy.values) {
        expect(field.max, p9r13Fields[field.id], reason: '$locale ${field.id}');
      }
    }
  });

  test('every_field_is_within_its_store_limit', () {
    for (final locale in locales) {
      for (final field in loadStoreCopy(locale).values) {
        final filled = fillTokens(field.text, values);
        expect(filled.trim(), isNotEmpty, reason: '$locale ${field.id}');
        expect(
          filled.length,
          lessThanOrEqualTo(field.max),
          reason: '$locale ${field.id} is ${filled.length} characters',
        );
      }
    }
  });

  test('names_are_the_app_name_token', () {
    for (final locale in locales) {
      final copy = loadStoreCopy(locale);
      expect(copy['play.title']!.text, '{{APP_NAME}}', reason: locale);
      expect(copy['appstore.name']!.text, '{{APP_NAME}}', reason: locale);
    }
  });

  test(
    'name_fields_keywords_captions_and_graphic_text_carry_no_trademarks',
    () {
      for (final locale in locales) {
        for (final field in loadStoreCopy(locale).values) {
          if (!isTrademarkFree(field.id)) continue;
          var filled = fillTokens(field.text, values);
          if (field.id == 'play.title' || field.id == 'appstore.name') {
            // The placeholder name's "for Android TV" (decision #12) is the
            // one allowed hit, and only in the two name fields.
            filled = filled.replaceFirst(appName, appName.split(' ').first);
          }
          expect(
            trademarks.allMatches(filled).map((m) => m[0]).toList(),
            isEmpty,
            reason: '$locale ${field.id}: $filled',
          );
        }
      }
    },
  );

  test('descriptions_end_with_the_trademark_notice', () {
    for (final locale in locales) {
      final copy = loadStoreCopy(locale);
      for (final id in ['play.full_description', 'appstore.description']) {
        expect(
          copy[id]!.text.trimRight(),
          endsWith(aboutTrademark(locale)),
          reason: '$locale $id',
        );
      }
    }
  });

  test('copy_never_borrows_from_the_competitor', () {
    for (final locale in locales) {
      final raw = File(
        '../docs/release/store-listing/$locale.md',
      ).readAsStringSync();
      for (final text in [raw, fillTokens(raw, values)]) {
        final lower = text.toLowerCase();
        for (final banned in const [
          'remote atv',
          'simha',
          'remote for android tv',
        ]) {
          expect(lower, isNot(contains(banned)), reason: '$locale: $banned');
        }
      }
    }
  });

  test('copy_promises_nothing_v1_lacks', () {
    final v1Lacks = RegExp(
      'voice|widget|watch|siri|alexa',
      caseSensitive: false,
    );
    for (final locale in locales) {
      for (final field in loadStoreCopy(locale).values) {
        final filled = fillTokens(field.text, values);
        expect(
          v1Lacks.allMatches(filled).map((m) => m[0]).toList(),
          isEmpty,
          reason: '$locale ${field.id}',
        );
      }
    }
  });

  test('ads_are_described_as_the_privacy_policy_does', () {
    // Ruling P9-C9: banners on Apps and Settings, and an occasional
    // full-screen ad (switchable by Remote Config) when leaving Settings,
    // never while pairing. No field may claim banners are the only ads.
    const rules = {
      'en': (
        mentionsAds: r'\bads?\b',
        banned: ['banner ads only', 'only banner ads', 'ads only'],
        disclosure: ['full-screen ad', 'leave settings', 'pair'],
      ),
      'ms': (
        mentionsAds: r'\biklan\b',
        banned: ['iklan sepanduk hanya', 'hanya iklan sepanduk'],
        disclosure: ['iklan skrin penuh', 'keluar dari tetapan', 'gandingkan'],
      ),
    };
    for (final locale in locales) {
      final rule = rules[locale]!;
      final mentionsAds = RegExp(rule.mentionsAds, caseSensitive: false);
      var described = 0;
      for (final field in loadStoreCopy(locale).values) {
        final lower = fillTokens(field.text, values).toLowerCase();
        for (final banned in rule.banned) {
          expect(
            lower,
            isNot(contains(banned)),
            reason: '$locale ${field.id}',
          );
        }
        // "Premium removes ads" alone doesn't describe where ads appear.
        final where = lower.replaceAll(RegExp(r'premium[^.\n]*'), '');
        if (!mentionsAds.hasMatch(where)) continue;
        described++;
        for (final phrase in rule.disclosure) {
          expect(where, contains(phrase), reason: '$locale ${field.id}');
        }
      }
      expect(described, greaterThanOrEqualTo(2), reason: locale);
    }
  });

  test('malay_copy_is_marked_unreviewed', () {
    final ms = File('../docs/release/store-listing/ms.md').readAsStringSync();
    expect(const LineSplitter().convert(ms).first, malayStatusLine);
  });

  test('the_parser_rejects_a_heading_without_a_block', () {
    expect(() => parseStoreCopy('## x (max 5)\n'), throwsFormatException);
  });

  test('the_parser_reads_fields_and_rejects_bad_shapes', () {
    const block = '```text\nHello\nthere\n```\n';
    final parsed = parseStoreCopy(
      '# Title\n\nNotes.\n\n## a.b (max 12)\n'
      '\nA note.\n\n$block\n## c (max 3)\n$block',
    );
    expect(parsed.keys, ['a.b', 'c']);
    expect(parsed['a.b']!.max, 12);
    expect(parsed['a.b']!.text, 'Hello\nthere');
    expect(
      parseStoreCopy('## a (max 1)\r\n```text\r\nx\r\n```\r\n')['a']!.text,
      'x',
    );
    for (final bad in [
      '## a (max 1)\n$block$block',
      '## a (max 1)\n$block## a (max 1)\n$block',
      '## a\n$block',
      '## a (max 1)\n```text\nunclosed\n',
      '$block## a (max 1)\n$block',
    ]) {
      expect(() => parseStoreCopy(bad), throwsFormatException, reason: bad);
    }
  });

  test('fill_tokens_replaces_known_values_and_keeps_the_rest', () {
    expect(
      fillTokens('{{A}} {{B}} {{C}}', {'A': 'x', 'B': null}),
      'x {{B}} {{C}}',
    );
  });
}
