import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/real_fonts.dart';
import '../helpers/test_catalogue.dart';
import '../release/store_copy.dart';
import 'store_frame.dart';

/// The store frame, the sets and the shot list of Ruling P9-R14. The
/// screenshots themselves are written by `store_screenshots_test.dart`.
void main() {
  setUpAll(loadRealFonts);

  test('every_store_set_matches_its_store_rules', () {
    const table = {
      StoreSet.playPhone: (Size(1080, 1920), Size(412, 732), 2.625),
      StoreSet.playTablet: (Size(2560, 1600), Size(1280, 800), 2.0),
      StoreSet.iphone69: (Size(1320, 2868), Size(440, 956), 3.0),
      StoreSet.ipad13: (Size(2752, 2064), Size(1376, 1032), 2.0),
    };
    expect(StoreSet.values.toSet(), table.keys.toSet());
    for (final MapEntry(key: set, value: (canvas, app, ratio))
        in table.entries) {
      expect(set.canvas, canvas, reason: '${set.name} canvas');
      expect(set.appSize, app, reason: '${set.name} app size');
      expect(set.pixelRatio, ratio, reason: '${set.name} pixel ratio');
    }

    // Google Play: each side 320–3840 px, the long side at most twice the
    // short one.
    for (final set in [StoreSet.playPhone, StoreSet.playTablet]) {
      expect(set.platform, TargetPlatform.android, reason: set.name);
      final Size(:width, :height) = set.canvas;
      for (final side in [width, height]) {
        expect(side, inInclusiveRange(320, 3840), reason: set.name);
      }
      expect(set.canvas.longestSide / set.canvas.shortestSide, lessThan(2));
    }
    // The App Store takes only its exact sizes, either way round.
    const apple = {
      StoreSet.iphone69: [Size(1320, 2868), Size(2868, 1320)],
      StoreSet.ipad13: [Size(2064, 2752), Size(2752, 2064)],
    };
    for (final MapEntry(key: set, value: sizes) in apple.entries) {
      expect(set.platform, TargetPlatform.iOS, reason: set.name);
      expect(sizes, contains(set.canvas), reason: set.name);
    }

    // The captured screen fits in the frame below the caption band, keeps
    // its shape, and is scaled down (never up, which would blur it).
    for (final set in StoreSet.values) {
      final screen = set.appSize * set.pixelRatio;
      final rect = StoreFrame.screenRect(set.canvas, screen);
      final band = set.canvas.height * StoreFrame.captionBand;
      expect(rect.top, greaterThanOrEqualTo(band), reason: set.name);
      expect(rect.bottom, lessThanOrEqualTo(set.canvas.height));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(set.canvas.width));
      expect(rect.width, closeTo(set.canvas.width * 0.78, 0.001));
      expect(rect.center.dx, closeTo(set.canvas.width / 2, 0.001));
      expect(
        rect.width / rect.height,
        closeTo(screen.width / screen.height, 0.001),
        reason: '${set.name} keeps the screen shape',
      );
      expect(rect.width, lessThanOrEqualTo(screen.width), reason: set.name);
    }
  });

  testWidgets('a_framed_shot_has_the_store_size_and_its_caption', (t) async {
    const set = StoreSet.playPhone;
    t.view
      ..physicalSize = set.canvas
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 4, 4),
      Paint()..color = const Color(0xFF00FF00),
    );
    final picture = recorder.endRecording();
    final screen = picture.toImageSync(4, 4);
    addTearDown(screen.dispose);
    addTearDown(picture.dispose);

    const key = ValueKey('frame');
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: StoreFrame(set: set, screen: screen, caption: 'Caption'),
      ),
    );
    final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(key));
    final image = (await t.runAsync(boundary.toImage))!;
    addTearDown(image.dispose);
    expect((image.width, image.height), (1080, 1920));
    expect(find.text('Caption'), findsOneWidget);
    final caption = t.renderObject<RenderParagraph>(find.text('Caption'));
    expect(caption.text.style?.fontFamily, 'Roboto');
    expect(caption.didExceedMaxLines, isFalse);
  });

  test('every_shot_has_a_caption_in_both_languages', () {
    expect(storeShots, hasLength(20));
    for (final set in StoreSet.values) {
      final shots = [
        for (final s in storeShots)
          if (s.set == set) s,
      ];
      final tablet = set == StoreSet.playTablet || set == StoreSet.ipad13;
      expect(shots, hasLength(tablet ? 2 : 8), reason: set.name);
      expect(
        {for (final s in shots) s.id},
        hasLength(shots.length),
        reason: '${set.name} ids are unique',
      );
      for (final s in shots) {
        expect(
          s.captionField,
          startsWith(tablet ? 'shot.tablet.' : 'shot.phone.'),
          reason: s.id,
        );
        expect(s.id, startsWith(s.captionField.split('.').last));
      }
    }
    final values = placeholderValues();
    for (final locale in ['en', 'ms']) {
      final copy = loadStoreCopy(locale);
      for (final s in storeShots) {
        final field = copy[s.captionField];
        expect(field, isNotNull, reason: '$locale ${s.captionField}');
        final text = fillTokens(field!.text, values).trim();
        expect(text, isNotEmpty, reason: '$locale ${s.captionField}');
        expect(text.length, lessThanOrEqualTo(field.max));
        expect(
          storeCaption(s, Locale(locale)),
          text,
          reason: 'the frame shows the store copy',
        );
      }
    }
  });

  test('shots_show_no_third_party_app_names', () {
    final catalogue = {
      for (final a in testCatalogue().apps) a.name.toLowerCase(),
    };
    final names = {for (final a in storeShortcuts) a.name};
    expect(names, {'Movies', 'Music', 'News', 'Sports', 'Kids', 'Photos'});
    expect(
      names.map((n) => n.toLowerCase()).toSet().intersection(catalogue),
      isEmpty,
    );
    final packages = {for (final a in testCatalogue().apps) a.package};
    for (final a in storeShortcuts) {
      expect(a.isCustom, isTrue, reason: '${a.name} is a custom shortcut');
      expect(a.iconUrl, isNull, reason: '${a.name} has no app icon');
      expect(packages, isNot(contains(a.package)), reason: a.name);
    }
    for (final tv in storeTvs) {
      for (final name in catalogue) {
        expect(tv.displayName.toLowerCase(), isNot(contains(name)));
      }
      expect(tv.displayName.toLowerCase(), isNot(contains('google')));
    }
    expect(storeSession().isDemo, isFalse, reason: 'no demo badge');
    expect(storeSession().tvName, 'Living Room TV');
  });

  test('the_screenshot_output_is_git_ignored', () async {
    final ProcessResult result;
    try {
      result = await Process.run('git', [
        'check-ignore',
        '-q',
        'build/store-screenshots/playPhone/en/01_touchpad.png',
      ], workingDirectory: '..').timeout(const Duration(seconds: 60));
    } on ProcessException {
      markTestSkipped('git is not on the PATH');
      return;
    }
    expect(result.exitCode, 0, reason: 'git check-ignore: ${result.stderr}');
  });
}
