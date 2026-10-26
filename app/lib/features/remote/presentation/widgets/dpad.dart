import 'dart:math' as math;

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
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

/// A round D-pad: four direction wedges around an OK disc (Ruling P4-R7).
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

  void _holdStart(LongPressStartDetails details) {
    final region = _regionAt(details.localPosition);
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

/// Paints the pad and describes its five buttons to screen readers.
class _DpadPainter extends CustomPainter {
  _DpadPainter({
    required this.colors,
    required this.labels,
    required this.pressed,
    required this.textDirection,
    required this.onSemanticTap,
  });

  final AppColors colors;
  final Map<DpadRegion, String> labels;
  final DpadRegion? pressed;
  final TextDirection textDirection;
  final ValueChanged<DpadRegion> onSemanticTap;

  static const double _sin45 = 0.7071067811865476;

  @override
  void paint(Canvas canvas, Size size) {
    final diameter = math.min(size.width, size.height);
    final c = size.center(Offset.zero);
    final radius = diameter / 2;
    final centerRadius = dpadCenterRadius(diameter);
    final accent = colors.accent;
    final tint = accent.withValues(alpha: 0.24);

    canvas
      ..drawCircle(c, radius, Paint()..color = colors.surfaceRaised)
      ..drawCircle(
        c,
        radius - 0.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = colors.outline,
      );

    if (pressed != null && pressed != DpadRegion.center) {
      final start = switch (pressed!) {
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
      canvas.drawPath(wedge, Paint()..color = tint);
    }

    canvas.drawCircle(c, centerRadius, Paint()..color = colors.surface);
    if (pressed == DpadRegion.center) {
      canvas.drawCircle(c, centerRadius, Paint()..color = tint);
    }
    canvas.drawCircle(
      c,
      centerRadius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent,
    );

    final chevron = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3
      ..color = colors.textPrimary;
    final reach = (centerRadius + radius) / 2;
    final arm = math.max<double>(7, radius * 0.07);
    for (final u in const [
      Offset(0, -1),
      Offset(0, 1),
      Offset(-1, 0),
      Offset(1, 0),
    ]) {
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

  @override
  bool shouldRepaint(_DpadPainter old) =>
      old.pressed != pressed || old.colors != colors;

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
