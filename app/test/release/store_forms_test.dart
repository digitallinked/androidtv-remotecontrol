import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'store_copy.dart' show fillTokens, placeholderValues;

/// The first line of every store-form and review draft (Task 9.11).
const String draftLine =
    '> DRAFT for the owner to paste. Confirm every answer against the '
    "console's current wording.";

/// The repo root; the tests run from `app/`.
final Directory repoRoot = Directory.current.parent;

/// The drafts this task writes, relative to `docs/release/`.
const List<String> draftNames = [
  'forms/play-data-safety.md',
  'forms/apple-app-privacy.md',
  'forms/content-rating.md',
  'forms/play-declarations.md',
  'forms/permissions.md',
  'forms/export-compliance.md',
  'forms/skadnetwork.md',
  'forms/adservices-permissions.md',
  'forms/app-ads-txt.md',
  'review/apple-review-notes.md',
  'review/demo-video-script.md',
];

/// The text of `docs/release/<name>`, with LF line endings: a Windows
/// checkout with `core.autocrlf` has CRLF, and the block patterns below
/// match LF only.
String releaseDoc(String name) => File(
  '${repoRoot.path}/docs/release/$name',
).readAsStringSync().replaceAll('\r\n', '\n');

/// The text of [path], relative to the repo root, decoded leniently so a
/// binary file can be scanned too.
String repoText(String path) => utf8.decode(
  File('${repoRoot.path}/$path').readAsBytesSync(),
  allowMalformed: true,
);

/// [file]'s path relative to the repo root, with forward slashes.
String relative(File file) {
  final root = repoRoot.absolute.uri.toString();
  return file.absolute.uri.toString().substring(root.length);
}

/// Every file under the repo-relative directory [dir], or none.
List<File> filesUnder(String dir, {bool recursive = true}) {
  final d = Directory('${repoRoot.path}/$dir');
  if (!d.existsSync()) return const [];
  return d.listSync(recursive: recursive).whereType<File>().toList();
}

/// The files that may hold the app's name or bundle id: the Android
/// sources and Gradle files, the iOS Runner, xcconfigs and project, and
/// `app/lib` without generated code, and the protocol package's `lib` and
/// `bin` (its client constants).
List<String> nameBearingFiles() {
  final android = [
    for (final f in filesUnder('app/android'))
      if (relative(f) case final path
          when !path.contains('/build/') &&
              !path.contains('/.gradle/') &&
              (path.startsWith('app/android/app/src/') ||
                  path.endsWith('.gradle') ||
                  path.endsWith('.gradle.kts')))
        path,
  ];
  final ios = [
    for (final f in filesUnder('app/ios/Runner')) relative(f),
    for (final f in filesUnder('app/ios/Flutter', recursive: false))
      if (f.path.endsWith('.xcconfig')) relative(f),
    'app/ios/Runner.xcodeproj/project.pbxproj',
  ];
  final lib = [
    for (final f in filesUnder('app/lib'))
      if (relative(f) case final path
          when !path.endsWith('.g.dart') &&
              !RegExp(
                r'^app/lib/app/l10n/app_localizations(_\w+)?\.dart$',
              ).hasMatch(path))
        path,
  ];
  final protocol = [
    for (final dir in ['packages/atv_remote/lib', 'packages/atv_remote/bin'])
      for (final f in filesUnder(dir))
        if (relative(f) case final path when !path.endsWith('.pb.dart')) path,
  ];
  return [...android, ...ios, ...lib, ...protocol]..sort();
}

void main() {
  test('forms_are_marked_draft', () {
    final written = {
      for (final dir in ['forms', 'review'])
        for (final f in filesUnder('docs/release/$dir'))
          if (f.path.endsWith('.md'))
            relative(f).substring('docs/release/'.length),
    };
    expect(written, containsAll(draftNames));
    for (final name in written) {
      expect(
        const LineSplitter().convert(releaseDoc(name)).first,
        draftLine,
        reason: name,
      );
    }
  });

  test('permissions_doc_explains_every_permission_we_declare', () {
    final manifest = repoText(
      'app/android/app/src/main/AndroidManifest.xml',
    );
    final declared = [
      for (final m in RegExp(
        r'<uses-permission\s+android:name="([^"]+)"',
      ).allMatches(manifest))
        m[1]!,
    ];
    expect(declared, isNotEmpty);
    final doc = releaseDoc('forms/permissions.md');
    for (final permission in declared) {
      expect(doc, contains(permission));
    }
  });

  test('skadnetwork_doc_matches_info_plist', () {
    final id = RegExp(r'\b[a-z0-9]+\.skadnetwork\b');
    final plist = repoText('app/ios/Runner/Info.plist');
    final inPlist = {
      for (final m in RegExp(
        r'<key>SKAdNetworkIdentifier</key>\s*<string>([^<]+)</string>',
      ).allMatches(plist))
        m[1]!,
    };
    expect(inPlist, isNotEmpty);
    final inDoc = {
      for (final m in id.allMatches(releaseDoc('forms/skadnetwork.md'))) m[0]!,
    };
    expect(inDoc, inPlist);
  });

  test('privacy_forms_cover_every_sdk', () {
    for (final name in [
      'forms/play-data-safety.md',
      'forms/apple-app-privacy.md',
    ]) {
      final doc = releaseDoc(name);
      for (final sdk in const [
        'Firebase Analytics',
        'Crashlytics',
        'Remote Config',
        'AdMob',
        'RevenueCat',
      ]) {
        expect(doc, contains(sdk), reason: '$name: $sdk');
      }
      // The same disclosure as privacy-policy.md (Ruling P9-C8).
      expect(
        doc,
        contains('occasional full-screen ad when you leave Settings'),
        reason: name,
      );
    }
  });

  test('data_safety_lists_the_skill_data_types', () {
    final doc = releaseDoc('forms/play-data-safety.md');
    for (final type in const [
      'Advertising ID',
      'Firebase Installation ID',
      'App set ID',
      'Approximate location',
      'Crash logs',
      'Diagnostics',
      'App interactions',
      'Purchase history',
    ]) {
      expect(doc, contains(type));
    }
  });

  test(
    'apple_privacy_lists_coarse_location_and_performance_data_and_tracking',
    () {
      final doc = releaseDoc('forms/apple-app-privacy.md');
      for (final text in const [
        'Coarse Location',
        'Performance Data',
        'Tracking: Yes',
      ]) {
        expect(doc, contains(text));
      }
    },
  );

  // Ruling P9-C12: Apple asks per data type, so a type AdMob collects is
  // linked even when a first-party SDK collects it too.
  test('apple_privacy_marks_every_type_admob_collects_as_linked', () {
    final rows = releaseDoc(
      'forms/apple-app-privacy.md',
    ).split('\n').where((l) => l.startsWith('| ') && l.contains('→')).toList();
    expect(rows, hasLength(greaterThanOrEqualTo(8)), reason: 'non-vacuous');
    for (final row in rows) {
      final cells = row.split('|').map((c) => c.trim()).toList();
      // ['', type, collected by, purposes, linked, tracking, '']
      final collectedBy = cells[2];
      final linked = cells[4];
      if (collectedBy.contains('AdMob')) {
        expect(linked, startsWith('**Yes**'), reason: cells[1]);
      }
    }
  });

  test('apple_privacy_not_collected_list_is_one_paragraph', () {
    final doc = releaseDoc('forms/apple-app-privacy.md');
    final paragraph = doc
        .split(RegExp(r'\n\s*\n'))
        .singleWhere((p) => p.startsWith('**Not collected**'));
    for (final category in const [
      'Contact Info',
      'Browsing History',
      'Search History',
      'Other Data',
    ]) {
      expect(paragraph, contains(category));
    }
    expect(paragraph, isNot(contains('Feedback e-mail')));
  });

  test('content_rating_cites_the_ads_guideline_not_the_kids_category', () {
    final doc = releaseDoc('forms/content-rating.md');
    expect(doc, isNot(contains('Guidelines 1.3')));
    expect(doc, contains('2.5.18'));
  });

  test('rename_checklist_names_every_file_that_holds_the_name_or_id', () {
    // Case-insensitive, so the database file name `remotely` counts too.
    final needles = [
      RegExp(r'com\.digitallinked\.atvremote', caseSensitive: false),
      RegExp('remotely for android tv', caseSensitive: false),
      RegExp('remotely dev', caseSensitive: false),
      RegExp('remotely', caseSensitive: false),
      // The protocol's client constants: the short id as a string literal.
      RegExp('[\'"]atvremote[\'"]'),
    ];
    final hits = [
      for (final path in nameBearingFiles())
        if (needles.any(repoText(path).contains)) path,
    ];
    // Non-vacuous: flavor.dart holds both names and ids today, the database
    // file name is lower-case, and the pairing service name is a constant.
    expect(
      hits,
      containsAll([
        'app/lib/app/flavor.dart',
        'app/lib/core/storage/app_database.dart',
        'packages/atv_remote/lib/src/pairing_client.dart',
      ]),
    );
    final checklist = releaseDoc('rename-checklist.md');
    final missing = [
      for (final path in hits)
        if (!checklist.contains(path)) path,
    ];
    expect(missing, isEmpty);
    // The store art and the warning the owner must see before upload.
    expect(checklist, contains('feature_graphic.title'));
    expect(
      checklist,
      contains('docs/release/store-assets/feature_graphic.png'),
    );
    expect(checklist.toLowerCase(), contains('permanent'));
  });

  test('review_notes_fit_apple_limit_after_filling', () {
    // App Review notes take 4,000 characters. Tokens are filled from
    // placeholders.json; unfilled ones count as their {{TOKEN}} text, and a
    // long video link is allowed for (P9-R13 counting).
    final doc = releaseDoc('review/apple-review-notes.md');
    final block = RegExp(
      r'## Notes \(paste this block\)\s*```text\n(.*?)```',
      dotAll: true,
    ).firstMatch(doc);
    expect(block, isNotNull);
    final values = {
      ...placeholderValues(),
      'DEMO_VIDEO_URL': 'https://www.youtube.com/watch?v=${'x' * 60}',
    };
    final filled = fillTokens(block![1]!, values).trimRight();
    expect(filled.length, lessThanOrEqualTo(4000));
  });

  test('play_app_access_instructions_fit_the_field', () {
    // Play Console's App access instructions field (owner to confirm the
    // limit in the console; 500 characters is the conservative figure).
    final doc = releaseDoc('forms/play-declarations.md');
    final block = RegExp(
      r'## App access: instructions for the reviewer.*?```text\n(.*?)```',
      dotAll: true,
    ).firstMatch(doc);
    expect(block, isNotNull);
    final filled = fillTokens(block![1]!, {
      ...placeholderValues(),
      'DEMO_VIDEO_URL': 'https://www.youtube.com/watch?v=${'x' * 11}',
    }).trimRight();
    expect(filled.length, lessThanOrEqualTo(500));
  });

  test('review_notes_give_the_demo_path_and_the_video_token', () {
    final doc = releaseDoc('review/apple-review-notes.md');
    expect(doc, contains('Try demo'));
    expect(doc, contains('{{DEMO_VIDEO_URL}}'));
  });

  test('app_ads_txt_template_uses_the_publisher_token', () {
    expect(
      releaseDoc('forms/app-ads-txt.md'),
      contains('google.com, {{ADMOB_PUBLISHER_ID}}, DIRECT, f08c47fec0942fa0'),
    );
  });

  test('forms_never_borrow_from_the_competitor', () {
    for (final name in [...draftNames, 'rename-checklist.md']) {
      final lower = releaseDoc(name).toLowerCase();
      for (final banned in const [
        'remote atv',
        'simha',
        'remote for android tv',
        // Its name for held keys; ours is "Natural hold" (P9-C10).
        'smooth press',
      ]) {
        expect(lower, isNot(contains(banned)), reason: '$name: $banned');
      }
    }
  });
}
