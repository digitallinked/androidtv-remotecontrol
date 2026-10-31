import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The families the Material text theme asks for on iOS (Typography's
/// Cupertino styles). The SDK ships no San Francisco, so Roboto stands in
/// for them: store screenshots of the App Store sets are drawn in Roboto.
const List<String> _iosTextFamilies = [
  'CupertinoSystemText',
  'CupertinoSystemDisplay',
];

/// Loads the real fonts that ship with the Flutter SDK running the test, so
/// text and icons draw as on a phone instead of in the test font (which
/// draws every glyph as a full-em box):
///
/// - Roboto regular, medium and bold, under `Roboto` (the Material text
///   theme on Android) and under the iOS text theme's families;
/// - `MaterialIcons`, the font of `Icons`.
///
/// The files come from the SDK's `bin/cache/artifacts/material_fonts`
/// ([materialFontsDir]), which exists on every platform the SDK runs on, so
/// a test that calls this runs on Linux CI as well. Fonts stay loaded for
/// the rest of the test file.
Future<void> loadRealFonts() async {
  final dir = materialFontsDir();
  ByteData read(String name) {
    final file = File('${dir.path}/$name');
    expect(file.existsSync(), isTrue, reason: '${file.path} exists');
    return ByteData.sublistView(file.readAsBytesSync());
  }

  final roboto = [
    for (final weight in ['regular', 'medium', 'bold'])
      read('roboto-$weight.ttf'),
  ];
  for (final family in ['Roboto', ..._iosTextFamilies]) {
    final loader = FontLoader(family);
    for (final data in roboto) {
      loader.addFont(Future.value(data));
    }
    await loader.load();
  }
  await (FontLoader(
    'MaterialIcons',
  )..addFont(Future.value(read('materialicons-regular.otf')))).load();
}

/// `bin/cache/artifacts/material_fonts` of the Flutter SDK that runs the
/// test: from `FLUTTER_ROOT`, or found above the test runner's executable.
Directory materialFontsDir() {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final dir = Directory('$root/bin/cache/artifacts/material_fonts');
    if (dir.existsSync()) return dir;
  }
  var dir = File(Platform.resolvedExecutable).parent;
  while (dir.parent.path != dir.path) {
    final fonts = Directory('${dir.path}/artifacts/material_fonts');
    if (fonts.existsSync()) return fonts;
    dir = dir.parent;
  }
  fail('the Flutter SDK material fonts were not found');
}
