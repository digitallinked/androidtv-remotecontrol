import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/config/app_config.dart';

/// The repo root; the tests run from `app/`.
final Directory repoRoot = Directory.current.parent;

/// The text of the repo-relative [path].
String repoDoc(String path) =>
    File('${repoRoot.path}/$path').readAsStringSync();

/// The launch-ops documents Task 9.12 writes, relative to the repo root.
const List<String> launchOpsDocs = [
  'docs/release/runbook.md',
  'docs/release/launch-ops/crashlytics-alerts.md',
  'docs/release/launch-ops/kill-switch-checklist.md',
  'docs/release/launch-ops/review-response-plan.md',
  'docs/release/launch-ops/v1.1-backlog.md',
];

/// The device-matrix rows of section 11 (Task 9.12; DM-117 is decision #58).
final List<String> phase9RowIds = [
  for (var n = 103; n <= 117; n++) 'DM-$n',
];

/// The cells of a Markdown table [row], split on unescaped `|`, without the
/// empty text before the first and after the last bar.
List<String> tableCells(String row) {
  final cells = row.trim().split(RegExp(r'(?<!\\)\|'));
  return [for (final c in cells.sublist(1, cells.length - 1)) c.trim()];
}

/// The lines of [doc] from the heading that starts with [heading] up to the
/// next heading of the same or a higher level.
List<String> section(String doc, String heading) {
  final lines = doc.split(RegExp(r'\r?\n'));
  final start = lines.indexWhere((l) => l.startsWith(heading));
  expect(start, isNot(-1), reason: 'no heading "$heading"');
  final level = RegExp('^#+').firstMatch(heading)![0]!.length;
  final next = RegExp('^#{1,$level} ');
  final end = lines.indexWhere(next.hasMatch, start + 1);
  return lines.sublist(start, end == -1 ? lines.length : end);
}

/// Every fenced ```text block in [doc].
List<String> textBlocks(String doc) => [
  for (final m in RegExp(
    r'```text\r?\n(.*?)```',
    dotAll: true,
  ).allMatches(doc))
    m[1]!,
];

void main() {
  test('kill_switch_checklist_names_the_real_keys_and_defaults', () {
    final doc = repoDoc('docs/release/launch-ops/kill-switch-checklist.md');
    final lines = doc.split(RegExp(r'\r?\n'));
    for (final key in const [
      'ads_banner_enabled',
      'ads_interstitial_enabled',
      'min_supported_version',
    ]) {
      final value = AppConfigValues.defaultsMap[key];
      expect(value, isNotNull, reason: '$key is not an AppConfig key');
      // A table row (or line) that names the key and its code default.
      expect(
        lines.where((l) => l.contains('`$key`') && l.contains('`$value`')),
        isNotEmpty,
        reason: '$key with its default `$value`',
      );
      expect(doc, contains('## `$key`'), reason: 'a section per key');
    }
    // The code's defaults, verbatim from app_config.dart.
    final source = repoDoc('app/lib/core/config/app_config.dart');
    final defaults = RegExp(
      r'static const Map<String, Object> defaultsMap = \{.*?\};',
      dotAll: true,
    ).firstMatch(source)![0]!;
    expect(
      doc.replaceAll('\r\n', '\n'),
      contains(defaults.replaceAll('\r\n', '\n')),
    );
  });

  test('runbook_links_only_files_that_exist', () {
    final docs =
        Directory('${repoRoot.path}/docs/release')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.md'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    final link = RegExp(r'\[[^\]]*\]\(([^)\s]+)\)');
    final broken = <String>[];
    var checked = 0;
    for (final doc in docs) {
      for (final m in link.allMatches(doc.readAsStringSync())) {
        final target = m[1]!;
        if (RegExp('^(https?|mailto):|^#').hasMatch(target)) continue;
        if (target.contains('{{')) continue;
        final path = Uri.decodeFull(target.split('#').first);
        final resolved = File.fromUri(doc.parent.uri.resolve(path));
        checked++;
        if (!resolved.existsSync()) broken.add('${doc.path}: $target');
      }
    }
    expect(broken, isEmpty);
    // The runbook links its sources; a parser that finds nothing is broken.
    expect(checked, greaterThan(10));
  });

  test('runbook_covers_every_owner_item', () {
    final runbook = repoDoc('docs/release/runbook.md');
    for (final item in const [
      'keystore',
      'key.properties',
      'Play App Signing',
      '12 testers',
      '14 days',
      'staged',
      '10 %',
      '50 %',
      '100 %',
      'TestFlight',
      'UMP',
      'app-ads.txt',
      'DM-068',
      'placeholders.json',
      // The commands and gates of P9-R2 and the device matrix.
      'tool/release.ps1 -Platform android -DryRun',
      'tool/release.sh --platform ios',
      'keytool -genkeypair',
      'keytool -printcert -jarfile',
      'dart tool/fill_release_docs.dart',
      'DM-056',
      'DM-057',
      'DM-058',
      'DM-059',
      'DM-060',
      'DM-061',
      'DM-066',
      'crashlytics-alerts.md',
      'kill-switch-checklist.md',
      'review-response-plan.md',
      'rename-checklist.md',
      // Ruling P9-C12's owner actions (the 9.11 fix round).
      'P9-C12',
      'Maximum ad content rating = G',
      'France',
    ]) {
      expect(runbook, contains(item), reason: item);
    }
    for (final id in phase9RowIds) {
      expect(runbook, contains(id), reason: id);
    }
    // Claude prepares; the owner does every step (P9-R1).
    expect(runbook, contains('P9-R1'));
  });

  test('device_matrix_phase_9_rows_hold_only_recorded_results', () {
    final doc = repoDoc('docs/knowledge/device-matrix.md');
    final rowId = RegExp(r'^\| (DM-\d{3}) \|');
    final all = [
      for (final line in doc.split(RegExp(r'\r?\n')))
        if (rowId.firstMatch(line) case final m?) m[1]!,
    ];
    expect(
      all.toSet().length,
      all.length,
      reason: 'duplicate row ids: $all',
    );

    final phase9 = section(doc, '## 11. Phase 9');
    final rows = {
      for (final line in phase9)
        if (rowId.firstMatch(line) case final m?) m[1]!: tableCells(line),
    };
    expect(rows.keys, phase9RowIds);
    for (final MapEntry(key: id, value: cells) in rows.entries) {
      expect(cells, hasLength(7), reason: id);
      expect(cells[1], startsWith('**Target:**'), reason: '$id steps');
      expect(cells[2], contains('**Record:**'), reason: '$id expected');
      // The matrix's own rule: a result is one of three words, and a row
      // that ran says on what and when.
      final [result, device, date, _] = cells.sublist(3);
      expect(result, isIn(['', 'Pass', 'Fail', 'Not run']), reason: id);
      if (result == 'Pass' || result == 'Fail') {
        expect(device, isNotEmpty, reason: '$id device');
        expect(
          date,
          matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')),
          reason: '$id date',
        );
      }
    }
    // `## 11` sits right before `## Coverage`.
    final headings = [
      for (final line in doc.split(RegExp(r'\r?\n')))
        if (line.startsWith('## ')) line,
    ];
    expect(
      headings.indexOf('## Coverage') - 1,
      headings.indexWhere((h) => h.startsWith('## 11. Phase 9')),
    );

    // Every new row is in the Phase 9 coverage table.
    final coverage = section(doc, '### Phase 9 tasks').join('\n');
    for (final id in phase9RowIds) {
      expect(coverage, contains(id), reason: 'coverage of $id');
    }

    // DM-107 proves the symbol uploads themselves, not only a readable
    // Dart non-fatal (which needs no symbols in v1).
    final dm107 = doc
        .split(RegExp(r'\r?\n'))
        .singleWhere((l) => l.startsWith('| DM-107 |'));
    for (final proof in const ['dwarfdump --uuid', 'mapping.txt', 'R8']) {
      expect(dm107, contains(proof), reason: 'DM-107: $proof');
    }

    // DM-060/061 keep their ids and now expect the P9-R6 behaviour.
    for (final id in const ['DM-060', 'DM-061']) {
      final row = doc
          .split(RegExp(r'\r?\n'))
          .singleWhere((l) => l.startsWith('| $id |'));
      for (final key in const [
        'settings.onboarding_complete',
        'privacy.att_preprompt_shown',
        'apps.shortcuts_seeded',
        'review.launch_count',
        'P9-R6',
      ]) {
        expect(row, contains(key), reason: '$id: $key');
      }
      expect(
        row,
        isNot(contains('is input for Phase 9')),
        reason: '$id still has the Phase 8 wording',
      );
      expect(tableCells(row).sublist(3, 6), ['', '', ''], reason: id);
    }
  });

  test('review_replies_are_our_own', () {
    final plan = repoDoc('docs/release/launch-ops/review-response-plan.md');
    final replies = textBlocks(plan);
    // One English reply per category, plus the Malay drafts.
    expect(replies.length, greaterThanOrEqualTo(14));
    // Each Malay draft stays marked until DM-068/DM-113 sign it off.
    expect(
      'Malay draft (UNREVIEWED):'.allMatches(plan).length,
      replies.length ~/ 2,
    );
    for (final reply in replies) {
      // Google Play's limit for a developer reply.
      expect(reply.trim().length, lessThanOrEqualTo(350), reason: reply);
      // The in-app button names (discoverEnterIp, en and ms) point to a
      // feature; they don't ask the reviewer for anything.
      final lower = reply
          .replaceAll('Enter IP address', '')
          .replaceAll('Masukkan alamat IP', '')
          .toLowerCase();
      for (final asksForData in [
        RegExp(r'\bip\b'),
        RegExp(r'\bmac\b'),
        RegExp('address'),
        RegExp('alamat'),
        RegExp(r'192\.168'),
        RegExp(r'\btv name\b|\bname of your tv\b|nama tv'),
      ]) {
        expect(lower, isNot(contains(asksForData)), reason: reply);
      }
    }
    for (final name in launchOpsDocs) {
      final lower = repoDoc(name).toLowerCase();
      for (final banned in const [
        'remote atv',
        'simha',
        'remote for android tv',
        'smooth press',
      ]) {
        expect(lower, isNot(contains(banned)), reason: '$name: $banned');
      }
    }
  });

  test('v1_1_backlog_holds_every_deferred_item', () {
    final backlog = repoDoc('docs/release/launch-ops/v1.1-backlog.md');
    for (final item in const [
      // The master plan's v1.1 list and Ruling P9-R16.
      'Home-screen widget',
      'Notification remote',
      'Voice search',
      'App Intents',
      'Watch apps',
      'iOS Wake-on-LAN',
      'mediation',
      'SKAdNetwork',
      'fastlane',
      'ExcludeSemantics',
      'banner while the keyboard is up',
      'predictive-back',
      'D-pad wedge depth',
      'Real app icons',
      'Malaysian app ids',
      // Device-run outcomes (decisions #10 and #23).
      'kImeTextMode',
      'Idle timeout',
      // Phase 9 deferrals, including the developer CLI (Task 9.7 review).
      'LocaleManager.setApplicationLocales',
      'privacyUsageSubtitle',
      'identity.json',
      'chmod 600',
      'rename fallback',
      'drop test',
      'gen_scripts_test',
    ]) {
      expect(backlog, contains(item), reason: item);
    }
    // Every row has an id, an item, a reason, a size and a dependency.
    final rows = [
      for (final line in backlog.split(RegExp(r'\r?\n')))
        if (line.startsWith('| V11-')) tableCells(line),
    ];
    expect(rows, isNotEmpty);
    for (final cells in rows) {
      expect(cells, hasLength(5), reason: cells.first);
      expect(
        cells[3],
        matches(RegExp(r'^(S|M|L)( each)?$')),
        reason: cells.first,
      );
      expect(cells.every((c) => c.isNotEmpty), isTrue, reason: cells.first);
    }
    final ids = [for (final cells in rows) cells.first];
    expect(ids.toSet(), hasLength(ids.length));
  });
}
