import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/storage/settings_store.dart';

import '../helpers/real_fonts.dart';
import 'store_frame.dart';

/// Where the generator writes, from `tool/web_screens.ps1` / `.sh`. Unset in
/// normal test runs, so the generator is skipped.
final String? _out = Platform.environment['WEB_SCREENS_OUT'];

Future<void> _dpadDark(SettingsStore s) async {
  await s.setThemePreference(ThemePreference.dark);
  await s.setNavigationStyle(NavigationStyle.dpad);
}

Future<void> _touchpadDark(SettingsStore s) async {
  await s.setThemePreference(ThemePreference.dark);
  await s.setNavigationStyle(NavigationStyle.touchpad);
}

/// The screens of the website (`web/public/screens/`): the real app on a
/// Play phone in English, with the store data and the store checks
/// (Ruling P9-R14), but bare: no frame, no caption. The site frames them.
///
/// The eight Play phone store shots, named without their number, plus the
/// remote in dark. The caption field is unused here.
final List<(String, StoreShot)> webShots = [
  for (final shot in storeShots.where((s) => s.set == StoreSet.playPhone))
    (shot.id.replaceFirst(RegExp(r'^\d+_'), ''), shot),
  (
    'touchpad_dark',
    const StoreShot(
      id: 'touchpad_dark',
      captionField: 'shot.phone.01',
      set: StoreSet.playPhone,
      brightness: Brightness.dark,
      prepare: _touchpadDark,
    ),
  ),
  (
    'dpad_dark',
    const StoreShot(
      id: 'dpad_dark',
      captionField: 'shot.phone.02',
      set: StoreSet.playPhone,
      brightness: Brightness.dark,
      prepare: _dpadDark,
    ),
  ),
];

void main() {
  setUpAll(loadRealFonts);

  testWidgets(
    'generator_writes_every_web_screen',
    (t) async {
      final out = Directory(_out!)..createSync(recursive: true);
      for (final (name, shot) in webShots) {
        final image = await captureScreen(t, shot, const Locale('en'));
        final png = (await t.runAsync(() async {
          try {
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            return data!.buffer.asUint8List(
              data.offsetInBytes,
              data.lengthInBytes,
            );
          } finally {
            image.dispose();
          }
        }))!;
        File('${out.path}/$name.png').writeAsBytesSync(png);
      }
      expect(
        out.listSync().whereType<File>().where((f) => f.path.endsWith('.png')),
        hasLength(webShots.length),
      );
    },
    skip: _out == null,
    timeout: const Timeout(Duration(minutes: 30)),
  );
}
