import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _manifest = 'ios/Runner/PrivacyInfo.xcprivacy';
const String _project = 'ios/Runner.xcodeproj/project.pbxproj';

void main() {
  // SQLite reads the size and timestamps of its own database files, and the
  // framework the sqlite3 build hook makes has no privacy manifest of its own.
  test('manifest_declares_why_sqlite_reads_file_timestamps', () {
    final manifest = File(_manifest).readAsStringSync();
    expect(manifest, contains('NSPrivacyAccessedAPICategoryFileTimestamp'));
    // C617.1: metadata of files inside the app container.
    expect(manifest, contains('C617.1'));
  });

  test('xcode_project_ships_the_privacy_manifest', () {
    final project = File(_project).readAsStringSync();

    final fileRef = RegExp(
      r'(\w{24}) /\* PrivacyInfo\.xcprivacy \*/ = \{isa = PBXFileReference; '
      r'lastKnownFileType = text\.xml; path = PrivacyInfo\.xcprivacy; '
      'sourceTree = "<group>"; };',
    ).firstMatch(project);
    expect(fileRef, isNotNull, reason: 'a PBXFileReference for the manifest');
    final fileId = fileRef!.group(1)!;

    final runnerGroup = RegExp(
      r'/\* Runner \*/ = \{\s*isa = PBXGroup;[^}]*path = Runner;',
    ).firstMatch(project);
    expect(
      runnerGroup?.group(0),
      contains('$fileId /* PrivacyInfo.xcprivacy */'),
    );

    final buildFile = RegExp(
      r'(\w{24}) /\* PrivacyInfo\.xcprivacy in Resources \*/ = '
      '\\{isa = PBXBuildFile; fileRef = $fileId ',
    ).firstMatch(project);
    expect(buildFile, isNotNull, reason: 'a PBXBuildFile for the manifest');

    final resources = RegExp(
      r'97C146EC1CF9000F007C117D /\* Resources \*/ = \{[^}]*\}',
    ).firstMatch(project);
    expect(
      resources?.group(0),
      contains(
        '${buildFile!.group(1)} /* PrivacyInfo.xcprivacy in Resources */',
      ),
    );

    final ids = RegExp(
      r'^\t\t([0-9A-F]{24}) ',
      multiLine: true,
    ).allMatches(project).map((m) => m.group(1)!).toList();
    expect(ids.toSet().length, ids.length, reason: 'object ids must be unique');
  });
}
