import 'package:flutter/widgets.dart';

/// Lays [child] out in the space it is given or, when that is shorter than
/// [minHeight], at [minHeight] in a scroll view, so a page squeezed by very
/// large text (or by the demo strip arriving above it) scrolls instead of
/// overflowing (Ruling P9-C6).
class ScrollWhenShort extends StatelessWidget {
  /// Creates the fallback around [child].
  const ScrollWhenShort({
    required this.minHeight,
    required this.child,
    super.key,
  });

  /// The least height [child] lays out in.
  final double minHeight;

  /// What is laid out.
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxHeight >= minHeight) return child;
      return SingleChildScrollView(
        child: SizedBox(height: minHeight, child: child),
      );
    },
  );
}
