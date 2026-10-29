import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'brand_mark.dart';

/// The non-pixel checks on the brand mark (Ruling P7-R6). They are untagged,
/// so Linux CI runs them too.
void main() {
  test('brand_svg_matches_the_painter_geometry', () {
    final file = File('assets/branding/brand_icon.svg');
    final svg = BrandMarkGeometry.svg(
      color: '#FFFFFF',
      background: '#3D5AFE',
      zoom: 1.3,
    );
    if (autoUpdateGoldenFiles) {
      file.writeAsStringSync(svg);
    } else {
      expect(file.readAsStringSync(), svg);
    }
  });

  test('the_mark_stays_inside_the_adaptive_safe_zone', () {
    // The adaptive foreground as its master paints it, in 108-unit space:
    // the painter's scale on a 108-unit canvas is exactly its zoom.
    const c = Offset(54, 54);
    final path = BrandMarkGeometry.path(iconForegroundPainter.zoom, c);
    final b = path.getBounds();
    var filled = 0;
    var farthest = 0.0;
    for (var x = b.left; x <= b.right; x += 0.5) {
      for (var y = b.top; y <= b.bottom; y += 0.5) {
        final p = Offset(x, y);
        if (path.contains(p)) {
          filled++;
          farthest = math.max(farthest, (p - c).distance);
        }
      }
    }
    expect(filled, greaterThan(0));
    // Every filled point lies inside the safe circle (radius 33).
    expect(farthest, lessThanOrEqualTo(33));
  });
}
