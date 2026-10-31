import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _strings = 'ios/Runner/ms.lproj/InfoPlist.strings';
const String _project = 'ios/Runner.xcodeproj/project.pbxproj';
const String _plist = 'ios/Runner/Info.plist';

/// The `"key" = "value";` pairs of an Apple `.strings` file.
Map<String, String> _parseStrings(String source) => {
  for (final m in RegExp(
    r'^"([^"]+)"\s*=\s*"((?:[^"\\]|\\.)*)";\s*$',
    multiLine: true,
  ).allMatches(source))
    m.group(1)!: m.group(2)!,
};

void main() {
  test('malay_purpose_strings_exist_and_name_the_app', () {
    final strings = _parseStrings(File(_strings).readAsStringSync());
    for (final key in [
      'NSLocalNetworkUsageDescription',
      'NSUserTrackingUsageDescription',
    ]) {
      final value = strings[key];
      expect(value, isNotNull, reason: '$key is in $_strings');
      expect(value!.trim(), isNotEmpty, reason: key);
      expect(value, contains('Remotely'), reason: key);
      expect(value, isNot(contains('Google')), reason: key);
    }
  });

  test('xcode_project_ships_the_malay_strings', () {
    final project = File(_project).readAsStringSync();
    expect(project, contains('path = ms.lproj/InfoPlist.strings;'));
    expect(project, contains('lastKnownFileType = text.plist.strings;'));

    // The variant group named InfoPlist.strings holds the ms file …
    final group = RegExp(
      r'(\w{24}) /\* InfoPlist\.strings \*/ = \{\s*isa = PBXVariantGroup;'
      r'[^}]*name = InfoPlist\.strings;',
    ).firstMatch(project);
    expect(group, isNotNull, reason: 'a PBXVariantGroup InfoPlist.strings');
    final groupId = group!.group(1)!;
    expect(group.group(0), contains('/* ms */'));

    // … sits in the Runner group, and is built into the Runner target's
    // Resources phase.
    final runnerGroup = RegExp(
      r'/\* Runner \*/ = \{\s*isa = PBXGroup;[^}]*path = Runner;',
    ).firstMatch(project);
    expect(runnerGroup?.group(0), contains('$groupId /* InfoPlist.strings */'));
    final buildFile = RegExp(
      r'(\w{24}) /\* InfoPlist\.strings in Resources \*/ = '
      '\\{isa = PBXBuildFile; fileRef = $groupId ',
    ).firstMatch(project);
    expect(buildFile, isNotNull, reason: 'a PBXBuildFile for the group');
    final resources = RegExp(
      r'97C146EC1CF9000F007C117D /\* Resources \*/ = \{[^}]*\}',
    ).firstMatch(project);
    expect(
      resources?.group(0),
      contains('${buildFile!.group(1)} /* InfoPlist.strings in Resources */'),
    );

    // Every object id is unique.
    final ids = RegExp(
      r'^\t\t([0-9A-F]{24}) ',
      multiLine: true,
    ).allMatches(project).map((m) => m.group(1)!).toList();
    expect(ids.toSet().length, ids.length, reason: 'duplicate object ids');

    final regions = RegExp(
      r'knownRegions = \(([^)]*)\);',
    ).firstMatch(project)!.group(1)!;
    expect(
      regions.split(',').map((r) => r.trim()).where((r) => r.isNotEmpty),
      containsAll(<String>['en', 'Base', 'ms']),
    );
  });

  test('info_plist_lists_english_and_malay', () {
    final plist = File(_plist).readAsStringSync();
    final list = RegExp(
      r'<key>CFBundleLocalizations</key>\s*<array>(.*?)</array>',
      dotAll: true,
    ).firstMatch(plist);
    expect(list, isNotNull, reason: 'CFBundleLocalizations is declared');
    expect(
      RegExp(
        '<string>([^<]*)</string>',
      ).allMatches(list!.group(1)!).map((m) => m.group(1)).toList(),
      ['en', 'ms'],
    );
  });
}
