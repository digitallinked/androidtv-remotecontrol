import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/real_fonts.dart';
import 'store_frame.dart';

/// Where the generator writes, from `tool/store_screenshots.ps1` / `.sh`
/// (Ruling P9-R14). Unset in normal test runs, so the generator is skipped.
final String? _out = Platform.environment['STORE_SCREENSHOTS_OUT'];

/// The store screenshot generator: every shot of [storeShots] in English and
/// Malay, framed, as `<out>/<set>/<locale>/<id>.png`. The PNGs are never
/// committed.
void main() {
  setUpAll(loadRealFonts);

  testWidgets(
    'generator_writes_every_shot',
    (t) async {
      final out = Directory(_out!);
      const locales = [Locale('en'), Locale('ms')];
      final written = <File, Size>{};
      for (final locale in locales) {
        for (final shot in storeShots) {
          final png = await renderFramed(t, shot, locale);
          final dir = Directory(
            '${out.path}/${shot.set.name}/${locale.languageCode}',
          )..createSync(recursive: true);
          final file = File('${dir.path}/${shot.id}.png')
            ..writeAsBytesSync(png);
          written[file] = shot.set.canvas;
        }
      }

      final files = out
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.png'))
          .toList();
      expect(files, hasLength(40), reason: 'no stale files in ${out.path}');
      expect(written, hasLength(40));
      for (final MapEntry(key: file, value: canvas) in written.entries) {
        final size = await t.runAsync(() async {
          final codec = await ui.instantiateImageCodec(file.readAsBytesSync());
          final frame = await codec.getNextFrame();
          final size = Size(
            frame.image.width.toDouble(),
            frame.image.height.toDouble(),
          );
          frame.image.dispose();
          codec.dispose();
          return size;
        });
        expect(size, canvas, reason: file.path);
      }
    },
    skip: _out == null,
    timeout: const Timeout(Duration(minutes: 30)),
  );
}
