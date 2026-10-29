import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The rectangles, in global coordinates, of every tappable control that is
/// on screen and not off stage: icon, back and close buttons, buttons, list
/// tiles and ink wells that react to taps, and switches and radios.
///
/// "On screen" means a tap at the control's centre would reach it, so rows
/// the list has built beyond its edge, and anything covered, are left out. A
/// row half scrolled out of its list counts only for the part that shows.
List<Rect> tappableRects(WidgetTester t) {
  final finders = <Finder>[
    find.byType(IconButton),
    find.byType(BackButton),
    find.byType(CloseButton),
    find.byType(ButtonStyleButton),
    find.byWidgetPredicate((w) => w is ListTile && w.onTap != null),
    find.byWidgetPredicate((w) => w is InkWell && w.onTap != null),
    find.byType(Switch),
    find.byWidgetPredicate((w) => w is Radio),
  ];
  final rects = <Rect>[];
  for (final finder in finders) {
    for (final element in finder.hitTestable().evaluate()) {
      final box = element.renderObject;
      if (box is! RenderBox || !box.hasSize || box.size.isEmpty) continue;
      var rect = box.localToGlobal(Offset.zero) & box.size;
      // A row half scrolled out of its list is only visible, and only
      // tappable, where the list is.
      final list = Scrollable.maybeOf(element)?.context.findRenderObject();
      if (list is RenderBox && list.hasSize) {
        rect = rect.intersect(list.localToGlobal(Offset.zero) & list.size);
      }
      if (rect.isEmpty) continue;
      rects.add(rect);
    }
  }
  return rects;
}

/// Expects every control in [tappableRects] to be at least [min] logical
/// pixels above or below [ad] wherever they overlap it horizontally.
///
/// Controls beside the ad (no horizontal overlap) are not constrained.
void expectClearance(WidgetTester t, Rect ad, {double min = 48}) {
  for (final rect in tappableRects(t)) {
    if (rect.right <= ad.left || rect.left >= ad.right) continue;
    final gap = rect.bottom <= ad.top
        ? ad.top - rect.bottom
        : rect.top >= ad.bottom
        ? rect.top - ad.bottom
        : -1.0;
    expect(
      gap,
      greaterThanOrEqualTo(min),
      reason: 'control $rect is $gap dp from the ad $ad',
    );
  }
}
