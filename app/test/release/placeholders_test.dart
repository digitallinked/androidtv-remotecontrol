import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/app_links.dart';

import '../../tool/fill_release_docs.dart';
import '../tool/release_fixture.dart' show requireTool, runTool;

/// The repo root; the tests run from `app/`.
final Directory repoRoot = Directory.current.parent;

/// `placeholders.json`, decoded.
Map<String, Map<String, Object?>> loadPlaceholders([Directory? root]) {
  final file = File(
    '${(root ?? repoRoot).path}/docs/release/placeholders.json',
  );
  final decoded = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  return {
    for (final e in decoded.entries) e.key: e.value! as Map<String, Object?>,
  };
}

/// Every Markdown file under `docs/release/`.
List<File> releaseDocs() =>
    Directory('${repoRoot.path}/docs/release')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.md'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

/// Everything written as `{{...}}`, untrimmed, so a malformed token such as
/// `{{ A }}` or `{{a}}` is caught. This is deliberately stricter than the
/// fill script, which trims and would accept `{{ A }}`: documents use the
/// exact `{{TOKEN}}` form only (Ruling P9-R11). Don't add a trim here.
final RegExp anyToken = RegExp(r'\{\{([^{}]*)\}\}');

void main() {
  test('placeholders_file_has_the_p9_r11_tokens_and_shape', () {
    final placeholders = loadPlaceholders();
    expect(placeholders.keys.toSet(), {
      'APP_NAME',
      'DEVELOPER_NAME',
      'DEVELOPER_ADDRESS',
      'SUPPORT_EMAIL',
      'SUPPORT_URL',
      'PRIVACY_POLICY_URL',
      'TERMS_URL',
      'EFFECTIVE_DATE',
      'ANALYTICS_RETENTION',
      'GOVERNING_LAW',
      'DEMO_VIDEO_URL',
      'ADMOB_PUBLISHER_ID',
      'APP_STORE_ID',
      'PLAY_PACKAGE',
    });
    for (final MapEntry(:key, :value) in placeholders.entries) {
      expect(value.keys.toSet(), {'value', 'about', 'code'}, reason: key);
      expect(value['value'], anyOf(isNull, isA<String>()), reason: key);
      expect(
        value['about'],
        isA<String>().having((s) => s, 'about', isNotEmpty),
      );
      expect(value['code'], anyOf(isNull, isA<String>()), reason: key);
    }
    expect(placeholders['APP_NAME']!['value'], 'Remotely for Android TV');
    expect(
      placeholders['PLAY_PACKAGE']!['value'],
      'com.digitallinked.atvremote',
    );
  });

  test('every_token_in_docs_release_is_registered', () {
    final keys = loadPlaceholders().keys.toSet();
    final offenders = <String>[];
    for (final doc in releaseDocs()) {
      for (final m in anyToken.allMatches(doc.readAsStringSync())) {
        if (!keys.contains(m[1])) offenders.add('${doc.path}: {{${m[1]}}}');
      }
    }
    expect(offenders, isEmpty);
  });

  test('every_registered_token_is_used_or_marked_code_only', () {
    final used = {
      for (final doc in releaseDocs())
        for (final m in anyToken.allMatches(doc.readAsStringSync())) m[1]!,
    };
    final unused = [
      for (final MapEntry(:key, :value) in loadPlaceholders().entries)
        if (!used.contains(key) && value['code'] == null) key,
    ];
    expect(unused, isEmpty);
  });

  test('app_links_match_the_placeholder_values', () {
    final placeholders = loadPlaceholders();
    final codes = {
      for (final MapEntry(:key, :value) in placeholders.entries)
        if (value['code'] != null) key: value['code'],
    };
    expect(codes, {
      'PRIVACY_POLICY_URL': 'AppLinks.privacyPolicy',
      'TERMS_URL': 'AppLinks.terms',
      'SUPPORT_EMAIL': 'AppLinks.supportEmail',
      'APP_STORE_ID': 'AppLinks.appStoreListing',
    });
    String? value(String token) => placeholders[token]!['value'] as String?;
    expect(AppLinks.privacyPolicy.toString(), value('PRIVACY_POLICY_URL'));
    expect(AppLinks.terms.toString(), value('TERMS_URL'));
    expect(AppLinks.supportEmail, value('SUPPORT_EMAIL'));
    expect(
      AppLinks.appStoreListing.toString(),
      endsWith('id${value('APP_STORE_ID')}'),
    );
  });

  test('no_other_lib_file_holds_a_link_or_support_address', () {
    final email = RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}');
    final offenders = <String>[];
    final lib = Directory('lib');
    for (final file in lib.listSync(recursive: true).whereType<File>()) {
      final path = file.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart')) continue;
      if (path.endsWith('lib/app/app_links.dart')) continue;
      // Generated from the ARB files, which hold no links.
      if (RegExp(
        r'lib/app/l10n/app_localizations(_\w+)?\.dart$',
      ).hasMatch(path)) {
        continue;
      }
      final text = file.readAsStringSync();
      if (text.contains('https://') ||
          text.contains('http://') ||
          email.hasMatch(text)) {
        offenders.add(path);
      }
    }
    expect(offenders, isEmpty);
  });

  group('fillReleaseDocs', () {
    late Directory root;
    late Directory out;

    setUp(() {
      root = Directory.systemTemp.createTempSync('release_fixture_');
      addTearDown(() => root.deleteSync(recursive: true));
      out = Directory('${root.path}/build/release-docs');
    });

    void writeFixture(
      Map<String, String?> values, {
      Map<String, String> docs = const {'a.md': '{{A}} {{B}}'},
    }) {
      File('${root.path}/docs/release/placeholders.json')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          jsonEncode({
            for (final MapEntry(:key, :value) in values.entries)
              key: {'value': value, 'about': 'test', 'code': null},
          }),
        );
      for (final MapEntry(:key, :value) in docs.entries) {
        File('${root.path}/docs/release/$key')
          ..createSync(recursive: true)
          ..writeAsStringSync(value);
      }
    }

    test('fill_replaces_every_token_and_lists_the_missing_ones', () async {
      writeFixture({'A': 'x', 'B': null});
      final result = await fillReleaseDocs(root: root, out: out);
      expect(result.written, hasLength(1));
      expect(result.written.single.readAsStringSync(), 'x {{B}}');
      expect(result.missing, {'B'});
    });

    test('fill_never_writes_inside_docs', () async {
      writeFixture(
        {'A': 'x', 'B': 'y'},
        docs: {'a.md': '{{A}}', 'sub/b.md': '{{B}}'},
      );
      final result = await fillReleaseDocs(root: root, out: out);
      final outPath = out.absolute.uri.toString();
      expect(result.written, hasLength(2));
      for (final file in result.written) {
        expect(file.absolute.uri.toString(), startsWith(outPath));
      }
      expect(
        File('${out.path}/sub/b.md').readAsStringSync(),
        'y',
      );
      expect(
        File('${root.path}/docs/release/a.md').readAsStringSync(),
        '{{A}}',
      );
      await expectLater(
        fillReleaseDocs(root: root, out: Directory('${root.path}/docs/out')),
        throwsArgumentError,
      );
      await expectLater(
        fillReleaseDocs(root: root, out: root),
        throwsArgumentError,
      );
    });

    test(
      'fill_only_empties_a_directory_below_build_or_outside_the_repo',
      () async {
        writeFixture({'A': 'x', 'B': 'y'});
        // A directory with other work in it, inside the repo but not in build/.
        final app = Directory('${root.path}/app')..createSync();
        File('${app.path}/keep.dart').writeAsStringSync('keep');
        for (final refused in [app, Directory('${root.path}/build')]) {
          await expectLater(
            fillReleaseDocs(root: root, out: refused),
            throwsArgumentError,
            reason: refused.path,
          );
        }
        expect(File('${app.path}/keep.dart').readAsStringSync(), 'keep');

        final outside = Directory.systemTemp.createTempSync('release_fixture_');
        addTearDown(() => outside.deleteSync(recursive: true));
        final result = await fillReleaseDocs(root: root, out: outside);
        expect(result.written.single.readAsStringSync(), 'x y');
      },
    );

    test('fill_treats_values_the_release_check_refuses_as_missing', () async {
      writeFixture(
        {
          'A': 'https://example.com/privacy',
          'B': 'support@example.com',
          'C': '0000000000',
          'D': 'real',
        },
        docs: {'a.md': '{{A}} {{B}} {{C}} {{D}} {{UNKNOWN}}'},
      );
      final result = await fillReleaseDocs(root: root, out: out);
      expect(
        result.written.single.readAsStringSync(),
        '{{A}} {{B}} {{C}} real {{UNKNOWN}}',
      );
      expect(result.missing, {'A', 'B', 'C', 'UNKNOWN'});
    });

    test('fill_is_idempotent_and_drops_stale_output', () async {
      writeFixture({'A': 'x', 'B': 'y'});
      File('${out.path}/stale.md')
        ..createSync(recursive: true)
        ..writeAsStringSync('old');
      final first = await fillReleaseDocs(root: root, out: out);
      final firstText = first.written.single.readAsStringSync();
      final second = await fillReleaseDocs(root: root, out: out);
      expect(second.written.single.readAsStringSync(), firstText);
      expect(second.missing, first.missing);
      expect(File('${out.path}/stale.md').existsSync(), isFalse);
    });

    test('fill_of_the_repo_keeps_every_placeholder_out', () async {
      final result = await fillReleaseDocs(root: repoRoot, out: out);
      final placeholders = loadPlaceholders();
      final text = result.written.map((f) => f.readAsStringSync()).join('\n');
      expect(text, isNot(contains('example.com')));
      expect(text, contains('Remotely for Android TV'));
      for (final token in result.missing) {
        expect(
          placeholders[token]?['value'],
          anyOf(isNull, contains('example.com'), '0000000000'),
          reason: token,
        );
      }
      expect(
        result.missing,
        containsAll(['PRIVACY_POLICY_URL', 'SUPPORT_EMAIL']),
      );
    });
  });

  group('fill_release_docs CLI', () {
    test('exits_1_on_missing_tokens_unless_allowed', () async {
      if (!await requireTool('dart')) return;
      final root = Directory.systemTemp.createTempSync('release_fixture_');
      addTearDown(() => root.deleteSync(recursive: true));
      File('${root.path}/docs/release/placeholders.json')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          jsonEncode({
            'A': {'value': null, 'about': 'test', 'code': null},
          }),
        );
      File('${root.path}/docs/release/a.md').writeAsStringSync('{{A}}');

      final refused = await runTool('dart', [
        'tool/fill_release_docs.dart',
        '--root',
        root.path,
      ]);
      expect(refused.exitCode, 1, reason: '${refused.stdout}${refused.stderr}');
      // The token is listed on its own line; the "Wrote ... to <path>" line
      // can't satisfy this, whatever the temp path holds.
      expect(
        const LineSplitter().convert(refused.stdout as String),
        contains('  A'),
      );

      final allowed = await runTool('dart', [
        'tool/fill_release_docs.dart',
        '--allow-missing',
        '--root',
        root.path,
      ]);
      expect(allowed.exitCode, 0, reason: '${allowed.stdout}${allowed.stderr}');
      expect(
        File('${root.path}/build/release-docs/a.md').readAsStringSync(),
        '{{A}}',
      );

      final usage = await runTool('dart', [
        'tool/fill_release_docs.dart',
        '--bogus',
      ]);
      expect(usage.exitCode, 64);
    });
  });
}
