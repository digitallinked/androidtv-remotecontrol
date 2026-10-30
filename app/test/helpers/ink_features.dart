import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every ink feature (splash or highlight) that a `Material` paints right
/// now, through the framework's `debugInkFeatures` test hook.
List<InkFeature> inkFeatures(WidgetTester t) => [
  for (final controller
      in t.allRenderObjects.whereType<MaterialInkController>())
    // `debugInkFeatures` is on the private render object; it is marked
    // `@visibleForTesting`.
    ...?((controller as dynamic).debugInkFeatures as List<InkFeature>?),
];

/// Checks that no interactive ink can be seen: no splash at all, and every
/// highlight transparent (static `Ink` decorations aren't checked). Then
/// disposes those transparent highlights.
///
/// Flutter fades a pressed highlight over 200 ms whatever the reduce-motion
/// flag says, and a transparent one still runs its (invisible) fade; it is
/// not motion anyone can see. Disposing it lets the caller check that
/// nothing else is animating.
void expectNoVisibleInk(WidgetTester t, String reason) {
  // A controller can be reached twice in the render tree walk.
  final features = inkFeatures(t).whereType<InteractiveInkFeature>().toSet();
  for (final feature in features) {
    expect(feature, isA<InkHighlight>(), reason: '$reason: a splash');
    final highlight = feature as InkHighlight;
    expect(
      highlight.color.a,
      0,
      reason: '$reason: a visible highlight ${highlight.color}',
    );
    highlight.dispose();
  }
}
