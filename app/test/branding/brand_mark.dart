import 'package:flutter/widgets.dart';

/// The geometry of our own D-pad mark (Ruling P7-R6): a ring with a centre dot
/// and four small outward triangles.
///
/// Units are on a 108 × 108 canvas centred on (54, 54), the adaptive-icon
/// canvas. The ring is an even-odd annulus, so the PNG masters and the SVG
/// share one fill rule.
abstract final class BrandMarkGeometry {
  /// The side of the design canvas, in units.
  static const double canvas = 108;

  /// The ring's outer radius (centre radius 22.5 plus half the 7-unit stroke).
  static const double ringOuter = 26;

  /// The ring's inner radius (centre radius 22.5 minus half the stroke).
  static const double ringInner = 19;

  /// The centre dot's radius.
  static const double dot = 7;

  /// The distance from the centre to the middle of each triangle's base.
  static const double triangleBase = 10.5;

  /// The distance from the centre to each triangle's apex.
  static const double triangleApex = 15.5;

  /// Half the width of each triangle's base.
  static const double triangleHalfWidth = 4;

  /// The four outward directions: up, right, down, left.
  static const List<Offset> _directions = [
    Offset(0, -1),
    Offset(1, 0),
    Offset(0, 1),
    Offset(-1, 0),
  ];

  /// Each triangle's corners in units relative to the centre: the base's two
  /// ends, then the apex.
  static Iterable<List<Offset>> _triangles() sync* {
    for (final d in _directions) {
      final side = Offset(-d.dy, d.dx);
      yield [
        d * triangleBase + side * triangleHalfWidth,
        d * triangleBase - side * triangleHalfWidth,
        d * triangleApex,
      ];
    }
  }

  /// The mark as one even-odd path, [scale] pixels per unit around [centre].
  static Path path(double scale, Offset centre) {
    final p = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: centre, radius: ringOuter * scale))
      ..addOval(Rect.fromCircle(center: centre, radius: ringInner * scale))
      ..addOval(Rect.fromCircle(center: centre, radius: dot * scale));
    for (final t in _triangles()) {
      p.addPolygon([for (final o in t) centre + o * scale], true);
    }
    return p;
  }

  /// The same mark as an SVG document (`viewBox="0 0 108 108"`), filled with
  /// [color], on [background] edge to edge when given, scaled by [zoom]
  /// around the centre.
  static String svg({
    required String color,
    String? background,
    double zoom = 1,
  }) {
    const c = canvas / 2;
    String n(double v) {
      final s = v.toStringAsFixed(3);
      return s.contains('.')
          ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
          : s;
    }

    String circle(double r) {
      final rr = n(r * zoom);
      return 'M${n(c + r * zoom)} ${n(c)}'
          'A$rr $rr 0 1 0 ${n(c - r * zoom)} ${n(c)}'
          'A$rr $rr 0 1 0 ${n(c + r * zoom)} ${n(c)}Z';
    }

    final d = StringBuffer()
      ..write(circle(ringOuter))
      ..write(circle(ringInner))
      ..write(circle(dot));
    for (final t in _triangles()) {
      final pts = [for (final o in t) const Offset(c, c) + o * zoom];
      d.write(
        'M${n(pts[0].dx)} ${n(pts[0].dy)}'
        'L${n(pts[1].dx)} ${n(pts[1].dy)}'
        'L${n(pts[2].dx)} ${n(pts[2].dy)}Z',
      );
    }

    final bg = background == null
        ? ''
        : '  <rect width="108" height="108" fill="$background"/>\n';
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108">\n'
        '$bg'
        '  <path fill="$color" fill-rule="evenodd" d="$d"/>\n'
        '</svg>\n';
  }
}

/// Paints the brand mark in [color], scaled to `size.shortestSide / 108 ×
/// zoom` around the centre, on [background] edge to edge when given.
class BrandMarkPainter extends CustomPainter {
  /// Creates a painter for the brand mark.
  const BrandMarkPainter({required this.color, this.background, this.zoom = 1});

  /// The mark's colour.
  final Color color;

  /// The full-bleed background, or `null` for transparent.
  final Color? background;

  /// How much larger than the 108-unit canvas the mark is drawn.
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    if (background case final bg?) {
      canvas.drawRect(Offset.zero & size, Paint()..color = bg);
    }
    final scale = size.shortestSide / BrandMarkGeometry.canvas * zoom;
    canvas.drawPath(
      BrandMarkGeometry.path(scale, size.center(Offset.zero)),
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(BrandMarkPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.background != background ||
      oldDelegate.zoom != zoom;
}
