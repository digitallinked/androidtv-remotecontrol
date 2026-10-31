import 'package:flutter/widgets.dart';

/// Lays [child] out in the space it is given or, when that is shorter than
/// [minHeight], at [minHeight] in a scroll view, so a page squeezed by very
/// large text (or by the demo strip arriving above it) scrolls instead of
/// overflowing (Ruling P9-C6).
///
/// [child] keeps its state when the height crosses [minHeight] either way:
/// it is moved between the two layouts under one global key. At full height
/// there is no scroll view, so nothing changes there.
class ScrollWhenShort extends StatefulWidget {
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
  State<ScrollWhenShort> createState() => _ScrollWhenShortState();
}

class _ScrollWhenShortState extends State<ScrollWhenShort> {
  final GlobalKey _child = GlobalKey();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final child = KeyedSubtree(key: _child, child: widget.child);
      if (constraints.maxHeight >= widget.minHeight) return child;
      return SingleChildScrollView(
        child: SizedBox(height: widget.minHeight, child: child),
      );
    },
  );
}
