import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ruling P8-R1: nothing about the user's TVs leaves the phone through
/// Android Auto Backup or device-to-device transfer.
const _manifestPath = 'android/app/src/main/AndroidManifest.xml';
const _rulesPath = 'android/app/src/main/res/xml/data_extraction_rules.xml';
const _arbPath = 'lib/app/l10n/app_en.arb';

/// Every domain a data extraction rule can name.
const _domains = {
  'root',
  'file',
  'database',
  'sharedpref',
  'external',
  'device_root',
  'device_file',
  'device_database',
  'device_sharedpref',
};

String _oneLine(String path) =>
    File(path).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');

/// The opening `<application ...>` tag of the manifest.
String _applicationTag() {
  final tag = RegExp('<application [^>]*>').firstMatch(_oneLine(_manifestPath));
  expect(tag, isNotNull, reason: 'no <application> tag in $_manifestPath');
  return tag!.group(0)!;
}

void _expectBackupOff({String? reason}) {
  final tag = _applicationTag();
  expect(tag, contains('android:allowBackup="false"'), reason: reason);
  expect(tag, contains('android:fullBackupContent="false"'), reason: reason);
}

/// The `exclude` domains inside `<section>...</section>` of the rules file.
List<String> _excluded(String rules, String section) {
  final body = RegExp(
    '<$section>(.*?)</$section>',
  ).firstMatch(rules);
  expect(body, isNotNull, reason: 'no <$section> in $_rulesPath');
  final text = body!.group(1)!;
  final excludes = RegExp(
    r'<exclude domain="([^"]+)" path="\."\s*/>',
  ).allMatches(text).map((m) => m.group(1)!).toList();
  // Every tag in the section was read: nothing the pattern could miss.
  expect(
    RegExp('<(?!!--)[a-z]').allMatches(text),
    hasLength(excludes.length),
    reason: '<$section> holds a tag other than <exclude domain path=".">',
  );
  return excludes;
}

void main() {
  test('allow_backup_is_off', _expectBackupOff);

  test('data_extraction_rules_are_referenced', () {
    expect(
      _applicationTag(),
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
    expect(File(_rulesPath).existsSync(), isTrue, reason: _rulesPath);
  });

  test('backup_and_transfer_exclude_every_domain', () {
    final rules = _oneLine(_rulesPath);
    expect(rules, isNot(contains('<include')));
    for (final section in const ['cloud-backup', 'device-transfer']) {
      final excluded = _excluded(rules, section);
      expect(excluded.toSet(), _domains, reason: section);
      expect(excluded, hasLength(_domains.length), reason: section);
    }
  });

  test('the_privacy_promise_is_backed_by_the_rules', () {
    final arb =
        jsonDecode(File(_arbPath).readAsStringSync()) as Map<String, dynamic>;
    expect(
      arb['privacyIntro'],
      contains('never leave this phone'),
      reason:
          'privacyIntro in $_arbPath promises that TV data never leaves '
          'the phone. If you changed that copy, check $_manifestPath and '
          '$_rulesPath still match it (Ruling P8-R1).',
    );
    _expectBackupOff(
      reason:
          'privacyIntro in $_arbPath promises that TV data never leaves '
          'the phone, which holds only while backup is off. Read '
          '$_manifestPath and Ruling P8-R1 before turning backup on.',
    );
  });
}
