import 'dart:math' as math;

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/foundation.dart' show mapEquals, visibleForTesting;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/relief.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/features/remote/application/key_input.dart';
import 'package:tv_remote/features/remote/presentation/key_labels.dart';

/// A part of the D-pad: the four directions and the OK disc.
enum DpadRegion {
  /// The wedge above the centre.
  up,

  /// The wedge below the centre.
  down,

  /// The wedge left of the centre.
  left,

  /// The wedge right of the centre.
  right,

  /// The OK disc in the middle.
  center,
}

/// The Android key code a press on [region] sends.
int dpadKeyCode(DpadRegion region) => switch (region) {
  DpadRegion.up => KeyCodes.dpadUp,
  DpadRegion.down => KeyCodes.dpadDown,
  DpadRegion.left => KeyCodes.dpadLeft,
  DpadRegion.right => KeyCodes.dpadRight,
  DpadRegion.center => KeyCodes.dpadCenter,
};

/// Radius of the OK disc of a pad with diameter [diameter]: 18% of the
/// diameter, and never under 28 dp (a 56 dp touch target).
double dpadCenterRadius(double diameter) => math.max(28, diameter * 0.18);

/// The region under [local] on a pad drawn in [size], or null outside it.
///
/// The pad is a circle as wide as the shorter side of [size], centred in it.
/// A point on the diagonal counts as horizontal.
DpadRegion? dpadRegionAt(Offset local, Size size) {
  final diameter = math.min(size.width, size.height);
  final d = local - size.center(Offset.zero);
  final r = d.distance;
  if (r > diameter / 2) return null;
  if (r <= dpadCenterRadius(diameter)) return DpadRegion.center;
  if (d.dx.abs() >= d.dy.abs()) {
    return d.dx < 0 ? DpadRegion.left : DpadRegion.right;
  }
  return d.dy < 0 ? DpadRegion.up : DpadRegion.down;
}

/// A round D-pad: four direction wedges around an OK disc (Ruling P4-R7),
/// drawn as the app's mark made into a control (decision #54): a backlit ring
/// that lights in the direction pressed, around the one accent key.
///
/// A tap sends the key of the region under the finger. Holding a region for
/// `kHoldThreshold` starts a hold on its key, and lifting (or a cancelled
/// touch, or removing the pad) ends it. A press outside the circle does
/// nothing. Screen readers get five buttons: Up, Down, Left, Right and OK.
///
/// The pad is a circle of diameter `min(maxWidth, maxHeight)` of its
/// constraints, kept between 160 and 320 dp, and centred.
class Dpad extends StatefulWidget {
  /// Creates a D-pad that sends its keys to [input].
  const Dpad({required this.input, super.key});

  /// Where the keys go. Hold callbacks keep the instance they started with.
  final KeyInput input;

  /// Smallest diameter of the pad, in dp.
  static const double minDiameter = 160;

  /// Largest diameter of the pad, in dp.
  static const double maxDiameter = 320;

  @override
  State<Dpad> createState() => _DpadState();
}

class _DpadState extends State<Dpad> {
  final GlobalKey _padKey = GlobalKey();

  /// The region under the pointer that is down, for the tint.
  DpadRegion? _pressed;
  int? _pressedPointer;

  /// The region that was tinted when the finger went down: what a tap sends,
  /// even if the finger slid across a boundary before lifting. Kept after the
  /// pointer-up (which clears the tint) because the tap callback follows it.
  DpadRegion? _downRegion;

  /// The region whose key is being held, and the input that started it.
  DpadRegion? _held;
  KeyInput? _holdInput;

  Size? get _padSize =>
      (_padKey.currentContext?.findRenderObject() as RenderBox?)?.size;

  DpadRegion? _regionAt(Offset local) {
    final size = _padSize;
    return size == null ? null : dpadRegionAt(local, size);
  }

  @override
  void dispose() {
    _endHold();
    super.dispose();
  }

  void _tapUp(TapUpDetails details) {
    final region = _downRegion;
    if (region != null) widget.input.tap(dpadKeyCode(region));
  }

  /// A hold is on the region the finger went down on, like a tap: not one
  /// the finger drifted into, and not one the spot falls in after the pad
  /// changed size under the finger.
  void _holdStart(LongPressStartDetails details) {
    final region = _downRegion;
    if (region == null) return;
    _held = region;
    _holdInput = widget.input;
    _holdInput!.holdStart(dpadKeyCode(region));
  }

  void _endHold() {
    final region = _held;
    final input = _holdInput;
    _held = null;
    _holdInput = null;
    if (region != null && input != null) input.holdEnd(dpadKeyCode(region));
  }

  void _setPressed(DpadRegion? region) {
    if (mounted && _pressed != region) setState(() => _pressed = region);
  }

  void _down(PointerDownEvent e) {
    if (_pressedPointer != null) return;
    _pressedPointer = e.pointer;
    _downRegion = _regionAt(e.localPosition);
    _setPressed(_downRegion);
  }

  void _release(PointerEvent e) {
    if (e.pointer != _pressedPointer) return;
    _pressedPointer = null;
    _setPressed(null);
  }

  void _semanticTap(DpadRegion region) => widget.input.tap(dpadKeyCode(region));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final direction = Directionality.of(context);
    final labels = {
      for (final r in DpadRegion.values) r: keyLabel(l10n, dpadKeyCode(r)),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math
            .min(constraints.maxWidth, constraints.maxHeight)
            .clamp(Dpad.minDiameter, Dpad.maxDiameter);
        return Center(
          child: SizedBox.square(
            key: _padKey,
            dimension: side,
            child: RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              // The five buttons below describe the pad; the detector's own
              // unlabeled tap node would only confuse a screen reader.
              excludeFromSemantics: true,
              gestures: {
                TapGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                      TapGestureRecognizer.new,
                      (r) => r.onTapUp = _tapUp,
                    ),
                LongPressGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      LongPressGestureRecognizer
                    >(
                      () =>
                          LongPressGestureRecognizer(duration: kHoldThreshold),
                      (r) => r
                        ..onLongPressStart = _holdStart
                        ..onLongPressEnd = ((_) => _endHold())
                        ..onLongPressCancel = _endHold,
                    ),
              },
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _down,
                onPointerUp: _release,
                onPointerCancel: _release,
                child: CustomPaint(
                  painter: _DpadPainter(
                    colors: colors,
                    brightness: Theme.of(context).brightness,
                    legend:
                        Theme.of(context).textTheme.titleMedium ??
                        const TextStyle(fontWeight: FontWeight.w600),
                    labels: labels,
                    pressed: _pressed,
                    textDirection: direction,
                    onSemanticTap: _semanticTap,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The region [painter], a D-pad's painter, tints as pressed; `null` for no
/// region or another painter. Lets tests read the tint without depending on
/// the private painter's fields.
@visibleForTesting
DpadRegion? dpadTintedRegion(CustomPainter? painter) =>
    painter is _DpadPainter ? painter.pressed : null;

/// Paints the pad and describes its five buttons to screen readers.
class _DpadPainter extends CustomPainter {
  _DpadPainter({
    required this.colors,
    required this.brightness,
    required this.legend,
    required this.labels,
    required this.pressed,
    required this.textDirection,
    required this.onSemanticTap,
  });

  final AppColors colors;
  final Brightness brightness;
  final TextStyle legend;
  final Map<DpadRegion, String> labels;
  final DpadRegion? pressed;
  final TextDirection textDirection;
  final ValueChanged<DpadRegion> onSemanticTap;

  static const double _sin45 = 0.7071067811865476;

  /// How far in from the pad's edge the backlit ring runs.
  static const double _ringInset = 10;

  /// Space between a seam's ends and what they point at.
  static const double _seamGap = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final diameter = math.min(size.width, size.height);
    final c = size.center(Offset.zero);
    final radius = diameter / 2;
    final centerRadius = dpadCenterRadius(diameter);
    final accent = colors.accent;
    final relief = Relief.of(colors, brightness);
    final body = Rect.fromCircle(center: c, radius: radius);

    // The pad, standing on its shadow: rim, then face.
    canvas
      ..drawCircle(
        c + const Offset(0, 3),
        radius - 3,
        Paint()
          ..color = relief.shadow
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      )
      ..drawCircle(c, radius, Paint()..shader = relief.rim.createShader(body))
      ..drawCircle(
        c,
        radius - 1,
        Paint()..shader = relief.face.createShader(body),
      );

    final ring = radius - _ringInset;
    final seam = Paint()
      ..strokeWidth = 1
      ..color = colors.outline;
    for (final (dx, dy) in const [
      (_sin45, _sin45),
      (-_sin45, _sin45),
      (-_sin45, -_sin45),
      (_sin45, -_sin45),
    ]) {
      final u = Offset(dx, dy);
      canvas.drawLine(
        c + u * (centerRadius + _seamGap),
        c + u * (ring - _seamGap),
        seam,
      );
    }

    // The backlit ring, and where the thumb is, the part of it that lights
    // up. Its arc stops short of the seams.
    canvas.drawCircle(
      c,
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent.withValues(alpha: 0.32),
    );
    final lit = pressed;
    if (lit != null && lit != DpadRegion.center) {
      final start = switch (lit) {
        DpadRegion.right => -math.pi / 4,
        DpadRegion.down => math.pi / 4,
        DpadRegion.left => 3 * math.pi / 4,
        _ => -3 * math.pi / 4,
      };
      final wedge = Path()
        ..moveTo(c.dx, c.dy)
        ..arcTo(
          Rect.fromCircle(center: c, radius: radius - 1),
          start,
          math.pi / 2,
          false,
        )
        ..close();
      canvas.drawPath(
        wedge,
        Paint()..color = accent.withValues(alpha: 0.16),
      );
      final arc = Rect.fromCircle(center: c, radius: ring);
      const trim = 0.09;
      for (final paint in [
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 6
          ..color = accent.withValues(alpha: 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 3
          ..color = accent,
      ]) {
        canvas.drawArc(arc, start + trim, math.pi / 2 - 2 * trim, false, paint);
      }
    }

    // The OK key, the one spot of colour on the remote.
    final down = lit == DpadRegion.center;
    if (!down) {
      canvas.drawCircle(
        c + const Offset(0, 2),
        centerRadius,
        Paint()
          ..color = relief.shadow
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
    canvas.drawCircle(
      c,
      centerRadius,
      Paint()..color = down ? Color.lerp(accent, colors.bg, 0.25)! : accent,
    );
    _paintLegend(canvas, c, centerRadius);

    final chevron = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3;
    final reach = (centerRadius + ring) / 2;
    final arm = math.max<double>(7, radius * 0.07);
    for (final (u, region) in const [
      (Offset(0, -1), DpadRegion.up),
      (Offset(0, 1), DpadRegion.down),
      (Offset(-1, 0), DpadRegion.left),
      (Offset(1, 0), DpadRegion.right),
    ]) {
      chevron.color = region == lit ? accent : colors.textPrimary;
      final perp = Offset(-u.dy, u.dx);
      final base = c + u * reach;
      final back = base - u * arm * 0.4;
      final tip = base + u * arm * 0.6;
      final wingA = back + perp * arm;
      final wingB = back - perp * arm;
      canvas.drawPath(
        Path()
          ..moveTo(wingA.dx, wingA.dy)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(wingB.dx, wingB.dy),
        chevron,
      );
    }
  }

  /// The OK key's word, shrunk to fit a language where it is longer.
  void _paintLegend(Canvas canvas, Offset c, double keyRadius) {
    final word = labels[DpadRegion.center];
    if (word == null) return;
    final room = keyRadius * 1.5;
    TextPainter layout(double fontSize) => TextPainter(
      text: TextSpan(
        text: word,
        style: legend.copyWith(
          color: colors.onAccent,
          fontSize: fontSize,
          height: 1,
        ),
      ),
      maxLines: 1,
      textDirection: textDirection,
    )..layout();
    var fontSize = keyRadius * 0.62;
    var text = layout(fontSize);
    if (text.width > room) {
      fontSize *= room / text.width;
      text.dispose();
      text = layout(fontSize);
    }
    text
      ..paint(canvas, c - Offset(text.width / 2, text.height / 2))
      ..dispose();
  }

  @override
  bool shouldRepaint(_DpadPainter old) =>
      old.pressed != pressed ||
      old.colors != colors ||
      old.brightness != brightness ||
      old.legend != legend ||
      !mapEquals(old.labels, labels);

  /// Where each region comes in a screen reader's reading order.
  static const Map<DpadRegion, double> _readingOrder = {
    DpadRegion.up: 0,
    DpadRegion.left: 1,
    DpadRegion.center: 2,
    DpadRegion.right: 3,
    DpadRegion.down: 4,
  };

  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) {
    final diameter = math.min(size.width, size.height);
    final c = size.center(Offset.zero);
    final radius = diameter / 2;
    final cr = dpadCenterRadius(diameter);
    final span = radius * _sin45;
    final rects = {
      DpadRegion.up: Rect.fromLTRB(
        c.dx - span,
        c.dy - radius,
        c.dx + span,
        c.dy - cr,
      ),
      DpadRegion.down: Rect.fromLTRB(
        c.dx - span,
        c.dy + cr,
        c.dx + span,
        c.dy + radius,
      ),
      DpadRegion.left: Rect.fromLTRB(
        c.dx - radius,
        c.dy - span,
        c.dx - cr,
        c.dy + span,
      ),
      DpadRegion.right: Rect.fromLTRB(
        c.dx + cr,
        c.dy - span,
        c.dx + radius,
        c.dy + span,
      ),
      DpadRegion.center: Rect.fromCircle(center: c, radius: cr),
    };
    return [
      for (final region in DpadRegion.values)
        CustomPainterSemantics(
          key: ValueKey(region),
          rect: rects[region]!,
          properties: SemanticsProperties(
            // Up, Left, OK, Right, Down: the order a screen reader reads,
            // whatever the pad's size does to the geometric order.
            sortKey: OrdinalSortKey(_readingOrder[region]!),
            label: labels[region],
            textDirection: textDirection,
            button: true,
            enabled: true,
            onTap: () => onSemanticTap(region),
          ),
        ),
    ];
  };

  @override
  bool shouldRebuildSemantics(_DpadPainter old) =>
      !mapEquals(old.labels, labels) || old.textDirection != textDirection;
}
