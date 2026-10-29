@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'brand_mark.dart';

/// The light accent `#3D5AFE`.
const Color _accent = Color(0xFF3D5AFE);

/// The dark accent `#6C8CFF`.
const Color _accentDark = Color(0xFF6C8CFF);

const Color _white = Color(0xFFFFFFFF);

/// The branding masters of Ruling P7-R6. Their baselines live in
/// `app/assets/branding/` and feed the icon and splash generators.
void main() {
  Future<void> master(
    WidgetTester tester, {
    required String name,
    required double px,
    required BrandMarkPainter painter,
  }) async {
    tester.view
      ..physicalSize = Size.square(px)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const k = ValueKey('master');
    // No MaterialApp: transparent pixels stay transparent.
    await tester.pumpWidget(
      RepaintBoundary(
        key: k,
        child: CustomPaint(size: Size.square(px), painter: painter),
      ),
    );
    await expectLater(
      find.byKey(k),
      matchesGoldenFile('../../assets/branding/$name.png'),
    );
  }

  testWidgets('icon_full_1024', (t) async {
    await master(
      t,
      name: 'icon_full',
      px: 1024,
      painter: const BrandMarkPainter(
        color: _white,
        background: _accent,
        zoom: 1.3,
      ),
    );
  });

  testWidgets('icon_foreground_1024', (t) async {
    await master(
      t,
      name: 'icon_foreground',
      px: 1024,
      painter: iconForegroundPainter,
    );
  });

  testWidgets('play_store_icon_512', (t) async {
    await master(
      t,
      name: 'play_store_icon_512',
      px: 512,
      painter: const BrandMarkPainter(
        color: _white,
        background: _accent,
        zoom: 1.3,
      ),
    );
  });

  testWidgets('splash_light_768', (t) async {
    await master(
      t,
      name: 'splash_light',
      px: 768,
      painter: const BrandMarkPainter(color: _accent, zoom: 1.3),
    );
  });

  testWidgets('splash_dark_768', (t) async {
    await master(
      t,
      name: 'splash_dark',
      px: 768,
      painter: const BrandMarkPainter(color: _accentDark, zoom: 1.3),
    );
  });

  testWidgets('splash_android12_light_1152', (t) async {
    await master(
      t,
      name: 'splash_android12_light',
      px: 1152,
      painter: const BrandMarkPainter(color: _accent),
    );
  });

  testWidgets('splash_android12_dark_1152', (t) async {
    await master(
      t,
      name: 'splash_android12_dark',
      px: 1152,
      painter: const BrandMarkPainter(color: _accentDark),
    );
  });
}
