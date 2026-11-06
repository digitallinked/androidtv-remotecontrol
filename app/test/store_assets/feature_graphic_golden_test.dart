@Tags(['golden'])
library;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/real_fonts.dart';
import '../release/store_copy.dart';
import 'store_frame.dart';

/// The Google Play feature graphic (Ruling P9-R14): 1024 × 500, opaque, our
/// own mark and the store copy's `feature_graphic.*` text in Roboto. The
/// baseline is the file uploaded to Play.
void main() {
  setUpAll(loadRealFonts);

  const key = ValueKey('feature_graphic');

  Future<void> pumpGraphic(WidgetTester t) async {
    t.view
      ..physicalSize = FeatureGraphic.size
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final copy = loadStoreCopy('en');
    final values = placeholderValues();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: FeatureGraphic(
          title: fillTokens(copy['feature_graphic.title']!.text, values),
          tagline: fillTokens(copy['feature_graphic.tagline']!.text, values),
        ),
      ),
    );
  }

  testWidgets('feature_graphic_1024x500', (t) async {
    await pumpGraphic(t);
    expect(find.text('Remotely'), findsOneWidget);
    await expectLater(
      find.byKey(key),
      matchesGoldenFile(
        '../../../docs/release/store-assets/feature_graphic.png',
      ),
    );
  });

  testWidgets('feature_graphic_is_opaque', (t) async {
    await pumpGraphic(t);
    final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(key));
    final pixels = (await t.runAsync(() async {
      final image = await boundary.toImage();
      try {
        expect((image.width, image.height), (1024, 500));
        return image.toByteData();
      } finally {
        image.dispose();
      }
    }))!;
    final rgba = pixels.buffer.asUint8List(
      pixels.offsetInBytes,
      pixels.lengthInBytes,
    );
    expect(rgba.length, 1024 * 500 * 4);
    var transparent = 0;
    for (var i = 3; i < rgba.length; i += 4) {
      if (rgba[i] != 255) transparent++;
    }
    expect(transparent, 0, reason: 'Play rejects a transparent graphic');
  });
}
