import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/features/apps/domain/app_catalogue.dart';

const _file = 'assets/catalogue/apps_v1.json';

AppCatalogue _load() => AppCatalogue.parse(File(_file).readAsStringSync());

const _sixRow = ['a.one', 'b.two', 'c.three', 'd.four', 'e.five', 'f.six'];

/// A catalogue document with the given [packages], all sharing [regions].
String _json({
  List<String> packages = _sixRow,
  List<String> regions = const ['*'],
  Map<String, List<String>> rows = const {'*': _sixRow},
}) {
  final regionJson = regions.map((r) => '"$r"').join(',');
  final apps = [
    for (final p in packages)
      '{"package":"$p","name":"App $p","regions":[$regionJson]}',
  ].join(',');
  final rowJson = rows.entries
      .map((e) => '"${e.key}":[${e.value.map((p) => '"$p"').join(',')}]')
      .join(',');
  return '{"version":1,"apps":[$apps],"defaultRows":{$rowJson}}';
}

void main() {
  late AppCatalogue c;

  setUpAll(() => c = _load());

  test('catalogue_parses_and_has_unique_packages', () {
    expect(c.apps.length, greaterThanOrEqualTo(50));
    expect(c.apps.map((a) => a.package).toSet(), hasLength(c.apps.length));
    for (final a in c.apps) {
      expect(a.name.trim(), isNotEmpty);
      expect(
        a.toEntry().launchLink,
        anyOf(startsWith('market://launch?id='), startsWith('https://')),
      );
      expect(a.regions, everyElement(matches(RegExp(r'^(\*|[A-Z]{2})$'))));
    }
  });

  test('catalogue_entries_carry_no_icon_urls_and_are_not_custom', () {
    for (final a in c.apps) {
      expect(a.toEntry().iconUrl, isNull);
      expect(a.toEntry().isCustom, isFalse);
    }
  });

  test('default_row_uses_device_region', () {
    String names(String? r) =>
        c.defaultShortcutsFor(r).map((e) => e.name).join(', ');
    expect(
      names('MY'),
      'Netflix, YouTube, Viu, Prime Video, iQIYI, Disney+ Hotstar',
    );
    expect(names('my'), names('MY'));
    expect(names('ZZ'), names(null));
    expect(c.defaultShortcutsFor(null).take(5).map((e) => e.package), [
      'com.netflix.ninja',
      'com.google.android.youtube.tv',
      'com.amazon.amazonvideo.livingroom',
      'com.disney.disneyplus',
      'com.spotify.tv.android',
    ]);
  });

  test('every_default_row_has_six_known_apps', () {
    expect(c.defaultRows, contains('*'));
    for (final MapEntry(:key, :value) in c.defaultRows.entries) {
      expect(value, hasLength(6), reason: key);
      expect(value.toSet(), hasLength(6), reason: key);
      for (final p in value) {
        expect(c.byPackage(p), isNotNull, reason: '$key: $p');
      }
    }
  });

  test('parse_rejects_duplicates_unknown_defaults_bad_regions_and_'
      'missing_star_row', () {
    // Sanity: the helper's shape is accepted when everything is valid.
    expect(() => AppCatalogue.parse(_json()), returnsNormally);

    // Duplicate package.
    expect(
      () => AppCatalogue.parse(_json(packages: [..._sixRow, 'a.one'])),
      throwsFormatException,
    );
    // Default-row package not in the catalogue.
    expect(
      () => AppCatalogue.parse(
        _json(
          rows: {
            '*': ['a.one', 'b.two', 'c.three', 'd.four', 'e.five', 'x.unknown'],
          },
        ),
      ),
      throwsFormatException,
    );
    // Bad regions: lower case, three letters, a digit.
    for (final bad in ['my', 'MYS', 'M1']) {
      expect(
        () => AppCatalogue.parse(_json(regions: [bad])),
        throwsFormatException,
        reason: bad,
      );
    }
    // No `*` row.
    expect(
      () => AppCatalogue.parse(_json(rows: {'MY': _sixRow})),
      throwsFormatException,
    );
    // A row that is not 6 long.
    expect(
      () => AppCatalogue.parse(
        _json(
          rows: {
            '*': ['a.one', 'b.two', 'c.three'],
          },
        ),
      ),
      throwsFormatException,
    );
    // A row that repeats a package (still 6 long).
    expect(
      () => AppCatalogue.parse(
        _json(
          rows: {
            '*': ['a.one', 'b.two', 'c.three', 'd.four', 'e.five', 'a.one'],
          },
        ),
      ),
      throwsFormatException,
    );
    // A bad region key in defaultRows.
    for (final bad in ['my', 'MYS', 'M1', '']) {
      expect(
        () => AppCatalogue.parse(_json(rows: {'*': _sixRow, bad: _sixRow})),
        throwsFormatException,
        reason: 'row key "$bad"',
      );
    }
  });

  test('parse_rejects_unknown_keys_and_other_versions', () {
    final valid = _json();
    expect(() => AppCatalogue.parse(valid), returnsNormally);

    for (final extra in [
      '"iconUrl":"https://example.com/i.png"',
      '"color":"#E50914"',
      '"colour":123',
      '"icon":null',
    ]) {
      expect(
        () => AppCatalogue.parse(
          valid.replaceFirst(
            '"package":"a.one"',
            '"package":"a.one",$extra',
          ),
        ),
        throwsFormatException,
        reason: extra,
      );
    }
    // Unknown top-level key.
    expect(
      () => AppCatalogue.parse(
        valid.replaceFirst('"version":1', '"version":1,"notes":"x"'),
      ),
      throwsFormatException,
    );
    // Versions other than 1, or a missing version.
    for (final v in ['2', '0', '"1"', 'null']) {
      expect(
        () => AppCatalogue.parse(
          valid.replaceFirst('"version":1', '"version":$v'),
        ),
        throwsFormatException,
        reason: 'version $v',
      );
    }
    expect(
      () => AppCatalogue.parse(valid.replaceFirst('"version":1,', '')),
      throwsFormatException,
    );
  });

  test('parse_rejects_missing_and_empty_fields', () {
    String one(String app) => '{"version":1,"apps":[$app],"defaultRows":{}}';
    for (final bad in [
      'not json',
      '[]',
      '{"version":1,"defaultRows":{}}',
      '{"version":1,"apps":[],"defaultRows":{}}',
      one('{"package":"","name":"X","regions":["*"]}'),
      one('{"package":"a.b","name":" ","regions":["*"]}'),
      one('{"package":"a.b","name":"X","regions":[]}'),
      one('{"package":"a.b","name":"X"}'),
    ]) {
      expect(() => AppCatalogue.parse(bad), throwsFormatException, reason: bad);
    }
  });

  test('launch_link_is_an_optional_override', () {
    final custom = AppCatalogue.parse(
      _json().replaceFirst(
        '"package":"a.one"',
        '"package":"a.one","launchLink":"https://example.com/one"',
      ),
    );
    expect(
      custom.byPackage('a.one')!.toEntry().launchLink,
      'https://example.com/one',
    );
    expect(
      c.byPackage('com.netflix.ninja')!.toEntry().launchLink,
      'market://launch?id=com.netflix.ninja',
    );
    expect(c.byPackage('no.such.app'), isNull);
  });

  test('is_available_in_matches_star_or_listed_region', () {
    final netflix = c.byPackage('com.netflix.ninja')!;
    final viu = c.byPackage('com.vuclip.viu')!;
    expect(netflix.isAvailableIn(null), isTrue);
    expect(netflix.isAvailableIn('ZZ'), isTrue);
    expect(viu.isAvailableIn('MY'), isTrue);
    expect(viu.isAvailableIn('my'), isTrue);
    expect(viu.isAvailableIn('US'), isFalse);
    expect(viu.isAvailableIn(null), isFalse);
  });

  test('search_matches_name_and_package_case_insensitively', () {
    expect(c.search('netf').map((a) => a.name), contains('Netflix'));
    expect(c.search('NINJA').map((a) => a.name), contains('Netflix'));
    expect(c.search(''), isEmpty);
    expect(c.search('   '), isEmpty);
    expect(c.search('zzzzqqqq'), isEmpty);
  });

  test('search_lists_region_available_apps_first', () {
    // "tv" matches the packages of both global and regional apps.
    final hits = c.search('tv', region: 'MY').map((a) => a.package).toList();
    final unavailable = c.search('tv').where((a) => !a.isAvailableIn('MY'));
    expect(unavailable, isNotEmpty);
    final firstUnavailable = hits.indexWhere(
      (p) => !c.byPackage(p)!.isAvailableIn('MY'),
    );
    final lastAvailable = hits.lastIndexWhere(
      (p) => c.byPackage(p)!.isAvailableIn('MY'),
    );
    expect(lastAvailable, greaterThanOrEqualTo(0));
    expect(firstUnavailable, greaterThan(lastAvailable));
    // Same set either way.
    expect(hits.toSet(), c.search('tv').map((a) => a.package).toSet());
  });

  test('suggested_for_region_lists_regional_then_global_apps', () {
    final packages = c.suggestedFor('MY').map((a) => a.package).toList();
    expect(packages.toSet(), hasLength(packages.length));
    expect(
      packages.indexOf('com.vuclip.viu'),
      lessThan(packages.indexOf('com.plexapp.android')),
    );
    expect(packages, contains('com.netflix.ninja'));
    expect(packages, isNot(contains('com.hulu.livingroomplus')));
    // Without a region: only the global apps.
    expect(c.suggestedFor(null).every((a) => a.regions.contains('*')), isTrue);
    // Lower-case region codes work too.
    expect(
      c.suggestedFor('my').map((a) => a.package),
      c.suggestedFor('MY').map((a) => a.package),
    );
  });

  test('default_rows_match_the_agreed_regions', () {
    const expected = {
      'SG': 'Netflix, YouTube, Disney+, Viu, Prime Video, iQIYI',
      'ID': 'Netflix, YouTube, Vidio, Disney+ Hotstar, Viu, Prime Video',
      'IN': 'JioHotstar, YouTube, Netflix, Prime Video, ZEE5, Sony LIV',
      'US': 'Netflix, YouTube, Prime Video, Hulu, Disney+, HBO Max',
      'GB': 'Netflix, BBC iPlayer, YouTube, Prime Video, Disney+, Channel 4',
      'AU': 'Netflix, YouTube, Stan, Prime Video, Disney+, ABC iview',
    };
    for (final MapEntry(:key, :value) in expected.entries) {
      expect(
        c.defaultShortcutsFor(key).map((e) => e.name).join(', '),
        value,
        reason: key,
      );
    }
  });

  test('catalogue_file_holds_no_icons_or_brand_colours', () {
    final text = File(_file).readAsStringSync();
    const allowed = {'package', 'name', 'regions', 'launchLink'};
    final root = jsonDecode(text) as Map<String, Object?>;
    expect(root.keys.toSet(), {'version', 'apps', 'defaultRows'});
    for (final app
        in (root['apps']! as List<Object?>).cast<Map<String, Object?>>()) {
      expect(
        allowed.containsAll(app.keys),
        isTrue,
        reason: '${app['package']}',
      );
    }
    // `http` may only appear inside an optional launchLink value.
    final withoutLinks = text.replaceAll(
      RegExp(r'"launchLink"\s*:\s*"[^"]*"'),
      '',
    );
    expect(withoutLinks, isNot(contains('http')));
    expect(text, isNot(matches(RegExp('#[0-9a-fA-F]{3,8}'))));
    expect(text, isNot(contains('0x')));
  });

  test('catalogue_file_stays_under_40kb', () {
    expect(File(_file).lengthSync(), lessThan(40 * 1024));
  });
}
