import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _manifest = 'ios/Runner/PrivacyInfo.xcprivacy';
const String _project = 'ios/Runner.xcodeproj/project.pbxproj';

void main() {
  // The framework the sqlite3 build hook makes has no privacy manifest of its
  // own, and `nm -u` on it lists stat, fstat, lstat, statfs and fstatfs
  // (tool/inspect_ios_product.sh prints this for every framework).
  test('manifest_declares_the_apis_sqlite_calls', () {
    final manifest = File(_manifest).readAsStringSync();
    // C617.1: metadata of files inside the app container.
    expect(manifest, contains('NSPrivacyAccessedAPICategoryFileTimestamp'));
    expect(manifest, contains('C617.1'));
    // E174.1: disk space, for an app that writes files.
    expect(manifest, contains('NSPrivacyAccessedAPICategoryDiskSpace'));
    expect(manifest, contains('E174.1'));
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
