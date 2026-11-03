import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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

/// The text of `docs/release/<name>`.
String releaseDoc(String name) =>
    File('${repoRoot.path}/docs/release/$name').readAsStringSync();

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
/// `app/lib` without generated code.
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
  return [...android, ...ios, ...lib]..sort();
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

  test('rename_checklist_names_every_file_that_holds_the_name_or_id', () {
    const needles = [
      'com.digitallinked.atvremote',
      'Remotely for Android TV',
      'Remotely Dev',
      'Remotely',
    ];
    final hits = [
      for (final path in nameBearingFiles())
        if (needles.any(repoText(path).contains)) path,
    ];
    // Non-vacuous: flavor.dart holds both names and ids today.
    expect(hits, contains('app/lib/app/flavor.dart'));
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
