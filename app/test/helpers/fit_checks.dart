import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rounding slack, in logical pixels, for edges that touch the viewport.
const double _slack = 0.5;

/// Checks that the widget [f] finds can be seen whole: its rect lies inside
/// the viewport of its nearest [Scrollable] (or inside the screen, if it
/// isn't in one) once [WidgetTester.ensureVisible] has scrolled to it.
///
/// A viewport can sit inside something smaller than the screen (a dialog's
/// body, a sheet), so a check against the screen alone misses a widget cut
/// off by its own scroll area (Phase 6 carry-over).
///
/// A widget longer than the viewport along the scroll axis can't be inside
/// it at once. It must then lie inside across the axis, and both its leading
/// and its trailing edge must scroll into the viewport.
///
/// It is `async` because scrolling needs a frame; await it.
Future<void> expectWithinViewport(
  WidgetTester t,
  Finder f, {
  required String reason,
}) async {
  expect(f, findsOneWidget, reason: '$reason: the widget is built');
  final scrollable = find.ancestor(of: f, matching: find.byType(Scrollable));
  if (scrollable.evaluate().isEmpty) {
    _expectInside(t.getRect(f), _screen(t), reason: '$reason: on screen');
    return;
  }
  final state = t.state<ScrollableState>(scrollable.first);
  final vertical = state.position.axis == Axis.vertical;
  final viewport = _viewportOf(t, state);

  await _scrollTo(t, f, alignment: 0);
  final rect = t.getRect(f);
  final along = vertical ? rect.height : rect.width;
  final room = vertical ? viewport.height : viewport.width;
  if (along <= room + _slack) {
    await _scrollTo(t, f, alignment: 0.5);
    _expectInside(t.getRect(f), viewport, reason: '$reason: in its viewport');
    return;
  }
  // Longer than the viewport: across the axis it must fit, and each end
  // must be reachable.
  final viewportNow = _viewportOf(t, state);
  final leading = t.getRect(f);
  if (vertical) {
    _expectAcross(
      leading.left,
      leading.right,
      viewportNow.left,
      viewportNow.right,
      reason: reason,
    );
    expect(
      leading.top,
      greaterThanOrEqualTo(viewportNow.top - _slack),
      reason: '$reason: its top scrolls into view',
    );
  } else {
    _expectAcross(
      leading.top,
      leading.bottom,
      viewportNow.top,
      viewportNow.bottom,
      reason: reason,
    );
    expect(
      leading.left,
      greaterThanOrEqualTo(viewportNow.left - _slack),
      reason: '$reason: its start scrolls into view',
    );
  }
  await _scrollTo(t, f, alignment: 1);
  final trailing = t.getRect(f);
  final viewportEnd = _viewportOf(t, state);
  if (vertical) {
    expect(
      trailing.bottom,
      lessThanOrEqualTo(viewportEnd.bottom + _slack),
      reason: '$reason: its bottom scrolls into view',
    );
  } else {
    expect(
      trailing.right,
      lessThanOrEqualTo(viewportEnd.right + _slack),
      reason: '$reason: its end scrolls into view',
    );
  }
}

Future<void> _scrollTo(
  WidgetTester t,
  Finder f, {
  required double alignment,
}) async {
  await Scrollable.ensureVisible(t.element(f), alignment: alignment);
  await t.pump();
}

/// The scroll area on screen: a viewport larger than the screen is cut to
/// it.
Rect _viewportOf(WidgetTester t, ScrollableState state) {
  final box = state.context.findRenderObject()! as RenderBox;
  return (box.localToGlobal(Offset.zero) & box.size).intersect(_screen(t));
}

Rect _screen(WidgetTester t) =>
    Offset.zero & t.view.physicalSize / t.view.devicePixelRatio;

void _expectAcross(
  double start,
  double end,
  double min,
  double max, {
  required String reason,
}) {
  expect(start, greaterThanOrEqualTo(min - _slack), reason: reason);
  expect(end, lessThanOrEqualTo(max + _slack), reason: reason);
}

void _expectInside(Rect rect, Rect bounds, {required String reason}) {
  expect(
    rect.left,
    greaterThanOrEqualTo(bounds.left - _slack),
    reason: '$reason (left $rect in $bounds)',
  );
  expect(
    rect.top,
    greaterThanOrEqualTo(bounds.top - _slack),
    reason: '$reason (top $rect in $bounds)',
  );
  expect(
    rect.right,
    lessThanOrEqualTo(bounds.right + _slack),
    reason: '$reason (right $rect in $bounds)',
  );
  expect(
    rect.bottom,
    lessThanOrEqualTo(bounds.bottom + _slack),
    reason: '$reason (bottom $rect in $bounds)',
  );
}
