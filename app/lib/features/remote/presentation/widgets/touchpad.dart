import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/features/remote/application/key_input.dart';
import 'package:tv_remote/features/remote/presentation/key_labels.dart';

/// A swipe-and-tap pad that drives the TV's D-pad (Ruling P4-R7).
///
/// - Swipe: the first step needs [firstStep] dp, each following step
///   [repeatStep] dp, along the dominant axis. One fast move can send several
///   steps.
/// - Tap: OK. Hold for `kLongPressTimeout`: a hold on OK.
/// - Tap with two fingers: Back.
/// - Movement of at least `kTouchSlop` that sends no step sends nothing; the
///   point where the finger lifts counts too (Ruling P7-R12).
///
/// A tap and a two-finger Back paint a ring that grows and fades where the
/// finger lifted (Ruling P7-R5); with reduce motion nothing is painted.
///
/// The pad claims every gesture that starts on it, so an ancestor scrollable
/// or pager never scrolls from here. Screen readers get one node with the
/// D-pad keys and Back as custom actions.
///
/// It fills the space its parent gives it, which must be bounded.
class Touchpad extends StatefulWidget {
  /// Creates a touchpad that sends its keys to [input].
  const Touchpad({required this.input, super.key});

  /// Where the keys go. Hold callbacks keep the instance they started with.
  final KeyInput input;

  /// Distance of the first step of a touch, in dp.
  static const double firstStep = 24;

  /// Distance of every later step of the same touch, in dp.
  static const double repeatStep = 40;

  /// Key of the layer that paints the trail, the edge glow and the tap pulse.
  /// With reduce motion the layer paints nothing.
  static const Key trailKey = ValueKey('touchpad-trail');

  @override
  State<Touchpad> createState() => _TouchpadState();
}

class _TouchpadState extends State<Touchpad>
    with SingleTickerProviderStateMixin {
  late final _PadGestures _gestures;
  late final _Feedback _feedback;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _gestures = _PadGestures(
      input: () => widget.input,
      onStep: _onStep,
      onTap: _onTap,
    );
    _feedback = _Feedback(createTicker);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) _feedback.clear();
  }

  @override
  void dispose() {
    _gestures.dispose();
    _feedback.dispose();
    super.dispose();
  }

  void _onStep(int keyCode) {
    if (!_reduceMotion) _feedback.glow(keyCode);
  }

  void _onTap(Offset localPosition) {
    if (!_reduceMotion) _feedback.pulse(localPosition);
  }

  void _trace(PointerEvent e) {
    if (!_reduceMotion && e.pointer == _gestures.primary) {
      _feedback.touch(e.localPosition);
    }
  }

  // Positions are local to the pad: it claims every gesture that starts on
  // it, so it doesn't move under the finger and distances are the same.
  void _down(PointerDownEvent e) {
    _gestures.down(e.pointer, e.localPosition);
    _trace(e);
  }

  void _move(PointerMoveEvent e) {
    _gestures.move(e.pointer, e.localPosition);
    _trace(e);
  }

  void _up(PointerUpEvent e) => _gestures.up(e.pointer, e.localPosition);

  void _cancel(PointerCancelEvent e) => _gestures.cancel(e.pointer);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        assert(
          constraints.hasBoundedWidth && constraints.hasBoundedHeight,
          'Touchpad needs bounded constraints; wrap it in Expanded or a '
          'SizedBox.',
        );
        return _pad(context);
      },
    );
  }

  Widget _pad(BuildContext context) {
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context);
    final radius = BorderRadius.circular(AppRadii.key * 1.5);

    final actions = <CustomSemanticsAction, VoidCallback>{
      for (final code in const [
        KeyCodes.dpadUp,
        KeyCodes.dpadDown,
        KeyCodes.dpadLeft,
        KeyCodes.dpadRight,
        KeyCodes.back,
      ])
        CustomSemanticsAction(label: keyLabel(l10n, code)): () =>
            widget.input.tap(code),
    };

    return Semantics(
      excludeSemantics: true,
      label: l10n.touchpadLabel,
      hint: l10n.touchpadHint,
      onTap: () => widget.input.tap(KeyCodes.dpadCenter),
      customSemanticsActions: actions,
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          EagerGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                EagerGestureRecognizer.new,
                (_) {},
              ),
        },
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _down,
          onPointerMove: _move,
          onPointerUp: _up,
          onPointerCancel: _cancel,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceRaised,
              borderRadius: radius,
              border: Border.all(color: colors.outline),
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  IgnorePointer(
                    child: CustomPaint(
                      key: Touchpad.trailKey,
                      painter: _FeedbackPainter(_feedback, colors.accent),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.l),
                    child: Center(
                      child: Text(
                        l10n.touchpadIdleHint,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Turns raw pointer events into remote keys. It knows nothing about widgets
/// or painting, so every rule of the touchpad reads in this one class.
///
/// A session starts with the first pointer down and ends when every pointer is
/// up. Pointers arrive as `down`, `move`, `up` and `cancel` with positions
/// local to the pad.
class _PadGestures {
  _PadGestures({
    required this.input,
    required this.onStep,
    required this.onTap,
  });

  /// The current input; a hold keeps the one it started with.
  final KeyInput Function() input;

  /// Called after each step with its D-pad key code.
  final void Function(int keyCode) onStep;

  /// Called after a centre tap or a two-finger Back, with where the last
  /// finger lifted.
  final void Function(Offset localPosition) onTap;

  /// Window for a two-finger tap, from the first pointer down.
  static const Duration _twoFingerWindow = Duration(milliseconds: 400);

  final Map<int, _Touch> _touches = {};
  int? _primary;

  /// The pointer that started the session, which drives steps, tap and hold.
  int? get primary => _primary;
  int _seen = 0;
  bool _dead = false;
  bool _twoFingers = false;
  bool _twoFingersStillTight = true;
  bool _windowOpen = true;
  bool _holdFired = false;
  int _steps = 0;
  late Offset _anchor;
  KeyInput? _holding;
  Timer? _holdTimer;
  Timer? _windowTimer;

  void down(int pointer, Offset position) {
    final first = _touches.isEmpty;
    _touches[pointer] = _Touch(position);
    if (first) {
      _startSession(pointer, position);
      return;
    }
    _seen++;
    if (_dead || _holding != null || _steps > 0) return; // ignored pointer
    _holdTimer?.cancel();
    final moved = _touches[_primary]?.reach ?? 0;
    if (_seen == 2 && moved < kTouchSlop) {
      _twoFingers = true;
    } else {
      _dead = true;
    }
  }

  void move(int pointer, Offset position) {
    final touch = _touches[pointer];
    if (touch == null) return;
    touch.moveTo(position);
    if (touch.reach >= Touchpad.firstStep) _twoFingersStillTight = false;
    if (_dead || _twoFingers || pointer != _primary || _holding != null) {
      return;
    }
    if (touch.reach >= kTouchSlop) _holdTimer?.cancel();
    _step(position);
  }

  void up(int pointer, Offset position) {
    final touch = _touches.remove(pointer);
    if (touch == null) return;
    // The finger may have travelled since its last move event: a flick that
    // lifts past the slop is not a tap.
    touch.moveTo(position);
    if (touch.reach >= Touchpad.firstStep) _twoFingersStillTight = false;
    if (pointer == _primary) _endHold();
    if (_touches.isEmpty) _finish(touch);
  }

  void cancel(int pointer) {
    if (_touches.remove(pointer) == null) return;
    _dead = true;
    _endHold();
    if (_touches.isEmpty) _endSession();
  }

  void dispose() {
    _endHold();
    _endSession();
    _touches.clear();
  }

  void _startSession(int pointer, Offset position) {
    _primary = pointer;
    _seen = 1;
    _dead = false;
    _twoFingers = false;
    _twoFingersStillTight = true;
    _windowOpen = true;
    _holdFired = false;
    _steps = 0;
    _anchor = position;
    _holdTimer = Timer(kLongPressTimeout, _startHold);
    _windowTimer = Timer(_twoFingerWindow, () => _windowOpen = false);
  }

  void _startHold() {
    if (_dead || _twoFingers || _steps > 0 || _touches.isEmpty) return;
    _holdFired = true;
    // Armed before reporting, so the release can't be lost.
    final held = input();
    _holding = held;
    held.holdStart(KeyCodes.dpadCenter);
  }

  void _endHold() {
    final held = _holding;
    if (held == null) return;
    _holding = null;
    held.holdEnd(KeyCodes.dpadCenter);
  }

  /// Sends a step for every threshold the finger has travelled from the
  /// anchor, along the dominant axis.
  void _step(Offset position) {
    while (true) {
      final delta = position - _anchor;
      final horizontal = delta.dx.abs() >= delta.dy.abs();
      final along = horizontal ? delta.dx : delta.dy;
      final threshold = _steps == 0 ? Touchpad.firstStep : Touchpad.repeatStep;
      if (along.abs() < threshold) return;
      final sign = along.isNegative ? -1.0 : 1.0;
      final keyCode = horizontal
          ? (sign > 0 ? KeyCodes.dpadRight : KeyCodes.dpadLeft)
          : (sign > 0 ? KeyCodes.dpadDown : KeyCodes.dpadUp);
      _steps++;
      _holdTimer?.cancel();
      input().tap(keyCode);
      onStep(keyCode);
      // Advance along the axis by the threshold; follow the finger across.
      _anchor = horizontal
          ? Offset(_anchor.dx + sign * threshold, position.dy)
          : Offset(position.dx, _anchor.dy + sign * threshold);
    }
  }

  /// All pointers are up: a tap or a two-finger tap may have happened.
  void _finish(_Touch last) {
    final wasDead = _dead;
    final steps = _steps;
    final held = _holdFired;
    final twoFingers = _twoFingers;
    final twoFingerTap = _seen == 2 && _twoFingersStillTight && _windowOpen;
    final primaryReach = last.reach;
    _endSession();
    if (wasDead || steps > 0 || held) return;
    if (twoFingers) {
      if (twoFingerTap) {
        input().tap(KeyCodes.back);
        onTap(last.position);
      }
      return;
    }
    if (primaryReach < kTouchSlop) {
      input().tap(KeyCodes.dpadCenter);
      onTap(last.position);
    }
  }

  void _endSession() {
    _holdTimer?.cancel();
    _windowTimer?.cancel();
    _holdTimer = null;
    _windowTimer = null;
    _primary = null;
  }
}

/// One pointer of a session: where it went down, where it is and how far it
/// ever got.
class _Touch {
  _Touch(this.start) : position = start;

  final Offset start;

  /// Where the pointer was last seen.
  Offset position;

  /// The largest distance from [start] so far.
  double reach = 0;

  void moveTo(Offset position) {
    this.position = position;
    final d = (position - start).distance;
    if (d > reach) reach = d;
  }
}

/// A recent touch point of the trail.
class _Point {
  _Point(this.position, this.at);

  final Offset position;
  final Duration at;
}

/// A recent step that lights the edge it points to.
class _Glow {
  _Glow(this.keyCode, this.at);

  final int keyCode;
  final Duration at;
}

/// A recent tap: a ring that grows and fades around where it landed.
class _Pulse {
  _Pulse(this.position, this.at);

  final Offset position;
  final Duration at;
}

/// Trail, glow and pulse state. A ticker runs only while something is still
/// fading.
class _Feedback extends ChangeNotifier {
  _Feedback(Ticker Function(TickerCallback onTick) createTicker) {
    _ticker = createTicker(_tick);
  }

  /// How long a trail point stays visible.
  static const Duration trailLife = Duration(milliseconds: 250);

  /// How long an edge glow takes to fade.
  static const Duration glowLife = AppMotion.standard;

  /// How long a tap pulse takes to grow and fade.
  static const Duration pulseLife = AppMotion.standard;

  late final Ticker _ticker;
  final List<_Point> points = [];
  final List<_Glow> glows = [];
  final List<_Pulse> pulses = [];
  Duration now = Duration.zero;

  void touch(Offset position) {
    _restartClock();
    points.add(_Point(position, now));
    _wake();
  }

  void glow(int keyCode) {
    _restartClock();
    glows.add(_Glow(keyCode, now));
    _wake();
  }

  void pulse(Offset position) {
    _restartClock();
    pulses.add(_Pulse(position, now));
    _wake();
  }

  /// The ticker's clock restarts at zero, so an entry added while it is idle
  /// must be stamped on the new clock, not on the stale time it stopped at.
  void _restartClock() {
    if (!_ticker.isActive) now = Duration.zero;
  }

  bool get _isEmpty => points.isEmpty && glows.isEmpty && pulses.isEmpty;

  void clear() {
    if (_isEmpty) return;
    points.clear();
    glows.clear();
    pulses.clear();
    notifyListeners();
  }

  void _wake() {
    if (!_ticker.isActive) unawaited(_ticker.start());
    notifyListeners();
  }

  void _tick(Duration elapsed) {
    now = elapsed;
    points.removeWhere((p) => now - p.at > trailLife);
    glows.removeWhere((g) => now - g.at > glowLife);
    pulses.removeWhere((p) => now - p.at > pulseLife);
    if (_isEmpty) _ticker.stop();
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

/// Paints the fading trail, the edge glows and the tap pulses.
class _FeedbackPainter extends CustomPainter {
  _FeedbackPainter(this.feedback, this.accent) : super(repaint: feedback);

  final _Feedback feedback;
  final Color accent;

  /// Depth of the edge glow.
  static const double _glowDepth = 24;

  /// Radius a tap pulse grows to.
  static const double _pulseRadius = 24;

  /// Accent alpha a tap pulse starts at.
  static const double _pulseAlpha = 0.35;

  @override
  void paint(Canvas canvas, Size size) {
    final now = feedback.now;
    final points = feedback.points;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8;
    for (var i = 1; i < points.length; i++) {
      final fade =
          1 -
          (now - points[i].at).inMicroseconds /
              _Feedback.trailLife.inMicroseconds;
      if (fade <= 0) continue;
      line.color = accent.withValues(alpha: 0.24 * fade);
      canvas.drawLine(points[i - 1].position, points[i].position, line);
    }

    for (final g in feedback.glows) {
      final fade =
          1 - (now - g.at).inMicroseconds / _Feedback.glowLife.inMicroseconds;
      if (fade <= 0) continue;
      final (rect, from, to) = switch (g.keyCode) {
        KeyCodes.dpadRight => (
          Rect.fromLTWH(size.width - _glowDepth, 0, _glowDepth, size.height),
          Alignment.centerLeft,
          Alignment.centerRight,
        ),
        KeyCodes.dpadLeft => (
          Rect.fromLTWH(0, 0, _glowDepth, size.height),
          Alignment.centerRight,
          Alignment.centerLeft,
        ),
        KeyCodes.dpadDown => (
          Rect.fromLTWH(0, size.height - _glowDepth, size.width, _glowDepth),
          Alignment.topCenter,
          Alignment.bottomCenter,
        ),
        _ => (
          Rect.fromLTWH(0, 0, size.width, _glowDepth),
          Alignment.bottomCenter,
          Alignment.topCenter,
        ),
      };
      final paint = Paint()
        ..shader = LinearGradient(
          begin: from,
          end: to,
          colors: [
            accent.withValues(alpha: 0),
            accent.withValues(alpha: 0.4 * fade),
          ],
        ).createShader(rect);
      canvas.drawRect(rect, paint);
    }

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final p in feedback.pulses) {
      final t =
          (now - p.at).inMicroseconds / _Feedback.pulseLife.inMicroseconds;
      if (t >= 1) continue;
      ring.color = accent.withValues(alpha: _pulseAlpha * (1 - t));
      canvas.drawCircle(
        p.position,
        _pulseRadius * AppMotion.curve.transform(t),
        ring,
      );
    }
  }

  @override
  bool shouldRepaint(_FeedbackPainter old) =>
      old.feedback != feedback || old.accent != accent;
}
