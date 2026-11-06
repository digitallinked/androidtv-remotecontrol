import 'package:flutter/material.dart';
import 'package:tv_remote/app/theme/tokens.dart';

/// The moulded look of the remote's keys, worked out from the palette in use
/// so that every colour style, Theater Mode and dynamic colour get it without
/// tokens of their own (decision #54).
///
/// There is one light, above the phone: a key's face is brightest at its top
/// edge, its rim catches the light on top and falls away below, and its
/// shadow drops straight down. Legends keep their contrast because the face
/// stays within a few percent of the palette's key colour.
@immutable
class Relief {
  /// The relief of [colors] on a [brightness] theme.
  factory Relief.of(AppColors colors, Brightness brightness) {
    Color mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;
    final key = colors.surfaceRaised;
    if (brightness == Brightness.dark) {
      return Relief._(
        faceTop: mix(key, Colors.white, 0.05),
        faceBottom: mix(key, Colors.black, 0.08),
        pressedFace: mix(key, Colors.black, 0.28),
        rimTop: mix(key, Colors.white, 0.16),
        rimBottom: mix(key, Colors.black, 0.30),
        shadow: Colors.black.withValues(alpha: 0.5),
        well: mix(colors.bg, Colors.black, 0.25),
        wellEdge: Colors.black.withValues(alpha: 0.5),
        wellDot: colors.outline,
      );
    }
    // In daylight a key is pale plastic standing on a greyer page: its face
    // is the surface colour, so it sits above the page instead of sinking
    // into it.
    return Relief._(
      faceTop: colors.surface,
      faceBottom: mix(colors.surface, key, 0.45),
      pressedFace: key,
      rimTop: mix(colors.outline, Colors.white, 0.4),
      rimBottom: colors.outline,
      shadow: colors.textPrimary.withValues(alpha: 0.10),
      well: key,
      wellEdge: colors.textPrimary.withValues(alpha: 0.08),
      wellDot: mix(key, colors.textSecondary, 0.26),
    );
  }

  const Relief._({
    required this.faceTop,
    required this.faceBottom,
    required this.pressedFace,
    required this.rimTop,
    required this.rimBottom,
    required this.shadow,
    required this.well,
    required this.wellEdge,
    required this.wellDot,
  });

  /// The top of a key's face.
  final Color faceTop;

  /// The bottom of a key's face.
  final Color faceBottom;

  /// A key's face while it is held down.
  final Color pressedFace;

  /// The top of a key's rim.
  final Color rimTop;

  /// The bottom of a key's rim.
  final Color rimBottom;

  /// The shadow under a key.
  final Color shadow;

  /// The floor of a recessed area, such as the touchpad.
  final Color well;

  /// The shade a recessed area's top edge casts on its floor.
  final Color wellEdge;

  /// The dots of the touchpad's matrix, unlit.
  final Color wellDot;

  /// A key's rim, as a gradient from top to bottom.
  LinearGradient get rim => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [rimTop, rimBottom],
  );

  /// A key's face, as a gradient from top to bottom.
  LinearGradient get face => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [faceTop, faceBottom],
  );

  /// The shadow under a key that is up.
  List<BoxShadow> get lift => [
    BoxShadow(color: shadow, offset: const Offset(0, 2), blurRadius: 4),
  ];
}

/// Access to the [Relief] of the current theme.
extension ReliefX on BuildContext {
  /// The relief of the nearest [Theme].
  Relief get relief => Relief.of(appColors, Theme.of(this).brightness);
}

/// A moulded key surface: [child] on a lit face inside a one-dp rim, on a
/// shadow. While [pressed] the key is down: a flat, darker face and no shadow.
///
/// The surface draws no ink. Put a transparent [Material] inside it for that.
class KeySurface extends StatelessWidget {
  /// Creates a surface with corners of [radius].
  const KeySurface({
    required this.radius,
    required this.child,
    this.pressed = false,
    super.key,
  });

  /// The corner radius. A value of half the height or more gives a stadium.
  final double radius;

  /// Whether the key is held down.
  final bool pressed;

  /// What the key shows.
  final Widget child;

  /// Width of the rim, which takes up room inside the surface.
  static const double rim = 1;

  @override
  Widget build(BuildContext context) {
    final relief = context.relief;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: relief.rim,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: pressed ? null : relief.lift,
      ),
      child: Padding(
        padding: const EdgeInsets.all(rim),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: pressed ? null : relief.face,
            color: pressed ? relief.pressedFace : null,
            borderRadius: BorderRadius.circular(radius - rim),
          ),
          child: child,
        ),
      ),
    );
  }
}
