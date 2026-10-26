import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:tv_remote/app/theme/tokens.dart';

/// A remote-control key: a rounded square with an icon, raised by default.
///
/// A short press calls [onTap]. Holding for [longPressDuration] calls
/// [onLongPressStart] (never [onTap]) and, when the finger lifts or the touch
/// is cancelled, [onLongPressEnd] exactly once. If the widget is removed while
/// held, [onLongPressEnd] is still called once. Without long-press callbacks
/// only taps are recognised.
///
/// A screen reader's "double-tap and hold" arrives as one semantic long-press
/// action, not a real hold. It calls [onSemanticLongPress] when given and
/// [onTap] otherwise, so a hold key is one press for TalkBack and VoiceOver.
class AppKeyButton extends StatefulWidget {
  /// Creates a key.
  const AppKeyButton({
    required this.semanticLabel,
    required this.icon,
    required this.onTap,
    super.key,
    this.onLongPressStart,
    this.onLongPressEnd,
    this.onSemanticLongPress,
    this.longPressDuration = kLongPressTimeout,
    this.size = AppSizes.keyMin,
    this.color,
  });

  /// Spoken label of the key, for example "Volume up".
  final String semanticLabel;

  /// Icon drawn in the centre; excluded from semantics.
  final Widget icon;

  /// Called on a short press.
  final VoidCallback onTap;

  /// Called when a hold reaches [longPressDuration].
  final VoidCallback? onLongPressStart;

  /// Called once when a hold that started ends, however it ends.
  final VoidCallback? onLongPressEnd;

  /// Called when a screen reader performs the long-press action. When null,
  /// that action calls [onTap]. The action is offered only when the key has
  /// long-press callbacks or this callback.
  final VoidCallback? onSemanticLongPress;

  /// How long a press must be held to count as a long press. It is applied
  /// when the key is first built.
  final Duration longPressDuration;

  /// Minimum width and height of the key.
  final double size;

  /// Fill of the key; defaults to `surfaceRaised`. The ripple and the press
  /// scale still show on a transparent key.
  final Color? color;

  @override
  State<AppKeyButton> createState() => _AppKeyButtonState();
}

class _AppKeyButtonState extends State<AppKeyButton> {
  bool _pressed = false;
  bool _holding = false;

  bool get _hasLongPress =>
      widget.onLongPressStart != null || widget.onLongPressEnd != null;

  @override
  void dispose() {
    _endHold();
    super.dispose();
  }

  // A pointer route can outlive the widget, so check `mounted`.
  void _setPressed(bool pressed) {
    if (mounted && _pressed != pressed) setState(() => _pressed = pressed);
  }

  void _startHold() {
    _holding = true;
    widget.onLongPressStart?.call();
  }

  void _endHold() {
    if (!_holding) return;
    _holding = false;
    widget.onLongPressEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppMotion.fast;
    final onSemanticLongPress =
        widget.onSemanticLongPress ?? (_hasLongPress ? widget.onTap : null);

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      excludeSemantics: true,
      onTap: widget.onTap,
      onLongPress: onSemanticLongPress,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: widget.size,
          minHeight: widget.size,
        ),
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: {
            TapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                  TapGestureRecognizer.new,
                  (r) => r.onTap = widget.onTap,
                ),
            if (_hasLongPress)
              LongPressGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    LongPressGestureRecognizer
                  >(
                    () => LongPressGestureRecognizer(
                      duration: widget.longPressDuration,
                    ),
                    (r) => r
                      ..onLongPressStart = ((_) => _startHold())
                      ..onLongPressEnd = ((_) => _endHold())
                      ..onLongPressCancel = _endHold,
                  ),
          },
          child: AnimatedScale(
            scale: _pressed ? AppMotion.pressScale : 1,
            duration: duration,
            curve: AppMotion.curve,
            child: Material(
              color: widget.color ?? colors.surfaceRaised,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.key),
              ),
              clipBehavior: Clip.antiAlias,
              child: _InkLayer(
                onPointerDown: () => _setPressed(true),
                onPointerUp: () => _setPressed(false),
                onPointerCancel: () {
                  _endHold();
                  _setPressed(false);
                },
                child: IconTheme.merge(
                  data: IconThemeData(color: colors.textPrimary),
                  child: Center(
                    widthFactor: 1,
                    heightFactor: 1,
                    child: widget.icon,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Listens to the raw pointer and paints the ink ripple on the [Material]
/// above it.
///
/// It owns the splash and sits below the [Material], so it is disposed first.
class _InkLayer extends StatefulWidget {
  const _InkLayer({
    required this.onPointerDown,
    required this.onPointerUp,
    required this.onPointerCancel,
    required this.child,
  });

  final VoidCallback onPointerDown;
  final VoidCallback onPointerUp;
  final VoidCallback onPointerCancel;
  final Widget child;

  @override
  State<_InkLayer> createState() => _InkLayerState();
}

class _InkLayerState extends State<_InkLayer> {
  InteractiveInkFeature? _splash;

  @override
  void dispose() {
    _splash?.dispose();
    super.dispose();
  }

  void _down(PointerDownEvent event) {
    widget.onPointerDown();
    // A second pointer must not leave the first ripple stuck.
    _splash?.cancel();
    late final InteractiveInkFeature splash;
    splash = InkRipple.splashFactory.create(
      controller: Material.of(context),
      referenceBox: context.findRenderObject()! as RenderBox,
      position: event.localPosition,
      color: context.appColors.accent.withValues(alpha: 0.24),
      containedInkWell: true,
      borderRadius: BorderRadius.circular(AppRadii.key),
      textDirection: Directionality.of(context),
      // A cancelled ripple is removed after its fade-out, by which time a newer
      // one may be current; only clear our own.
      onRemoved: () {
        if (identical(_splash, splash)) _splash = null;
      },
    );
    _splash = splash;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _down,
      onPointerUp: (_) {
        _splash?.confirm();
        widget.onPointerUp();
      },
      onPointerCancel: (_) {
        _splash?.cancel();
        widget.onPointerCancel();
      },
      child: widget.child,
    );
  }
}
