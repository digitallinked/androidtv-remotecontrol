import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';

/// Ruling P9-R7: Android 13+ lists the app's languages in its per-app
/// language settings. The list is written by hand, so it must match the
/// translations the app ships.
const _manifestPath = 'android/app/src/main/AndroidManifest.xml';
const _configPath = 'android/app/src/main/res/xml/locales_config.xml';
const _arbDir = 'lib/app/l10n';

String _oneLine(String path) =>
    File(path).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');

/// The language codes of the ARB files, from `app_<code>.arb`.
Set<String> _arbLocales() => {
  for (final file in Directory(_arbDir).listSync().whereType<File>())
    if (RegExp(r'app_(\w+)\.arb$').firstMatch(file.path) case final m?)
      m.group(1)!,
};

void main() {
  test('android_declares_its_app_languages', () {
    final tag = RegExp(
      '<application [^>]*>',
    ).firstMatch(_oneLine(_manifestPath));
    expect(tag, isNotNull, reason: 'no <application> tag in $_manifestPath');
    expect(
      tag!.group(0),
      contains('android:localeConfig="@xml/locales_config"'),
    );
    expect(File(_configPath).existsSync(), isTrue, reason: _configPath);
  });

  test('the_locale_config_lists_exactly_the_arb_locales', () {
    final config = _oneLine(_configPath);
    final body = RegExp(
      '<locale-config xmlns:android="http://schemas.android.com/apk/res/android"'
      r'\s*>(.*)</locale-config>',
    ).firstMatch(config);
    expect(body, isNotNull, reason: 'no <locale-config> root in $_configPath');
    final text = body!.group(1)!;

    final names = RegExp(
      r'<locale android:name="([^"]+)"\s*/>',
    ).allMatches(text).map((m) => m.group(1)!).toList();
    // Every tag in the file was read: nothing the pattern could miss.
    expect(
      RegExp('<(?!!--)[a-z]').allMatches(text),
      hasLength(names.length),
      reason: '$_configPath holds a tag other than <locale android:name>',
    );

    final arb = _arbLocales();
    expect(arb, {'en', 'ms'});
    expect(names, hasLength(names.toSet().length), reason: 'a duplicate');
    expect(names.toSet(), arb, reason: '$_configPath vs $_arbDir/app_*.arb');
    expect(
      names.toSet(),
      {
        for (final locale in AppLocalizations.supportedLocales)
          locale.toLanguageTag(),
      },
      reason: '$_configPath vs AppLocalizations.supportedLocales',
    );
  });
}
