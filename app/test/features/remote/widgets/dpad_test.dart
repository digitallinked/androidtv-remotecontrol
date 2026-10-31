import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/features/remote/application/key_input.dart';
import 'package:tv_remote/features/remote/presentation/widgets/dpad.dart';

import '../../../helpers/key_input_recorder.dart';
import '../../../helpers/pump_app.dart';

void main() {
  late KeyInputRecorder rec;

  setUp(() => rec = KeyInputRecorder());

  Future<void> pumpPad(
    WidgetTester t, {
    double side = 300,
    double textScale = 1,
    bool disableAnimations = false,
  }) => pumpApp(
    t,
    SizedBox(
      width: side,
      height: side,
      child: Dpad(input: rec),
    ),
    textScale: textScale,
    disableAnimations: disableAnimations,
  );

  Offset centre(WidgetTester t) => t.getCenter(find.byType(Dpad));

  const up = Offset(0, -100);
  const down = Offset(0, 100);
  const left = Offset(-100, 10);
  const right = Offset(100, -10);

  test('dpad_hit_regions_map_to_directions', () {
    const s = Size(300, 300);
    const c = Offset(150, 150);
    expect(dpadRegionAt(c, s), DpadRegion.center);
    expect(dpadRegionAt(c + const Offset(0, -100), s), DpadRegion.up);
    expect(dpadRegionAt(c + const Offset(0, 100), s), DpadRegion.down);
    expect(dpadRegionAt(c + const Offset(-100, 10), s), DpadRegion.left);
    expect(dpadRegionAt(c + const Offset(100, -10), s), DpadRegion.right);
    expect(dpadRegionAt(const Offset(2, 2), s), isNull);
    expect(dpadRegionAt(c + const Offset(70, 70), s), DpadRegion.right);
  });

  test('dpad_regions_use_the_smaller_side_and_the_centre_radius', () {
    // A 400 x 200 area holds a circle of diameter 200 in its middle.
    const s = Size(400, 200);
    expect(dpadRegionAt(const Offset(200, 100), s), DpadRegion.center);
    expect(dpadRegionAt(const Offset(200 + 90, 100), s), DpadRegion.right);
    expect(dpadRegionAt(const Offset(200 + 110, 100), s), isNull);
    // centerRadius(d) = max(28, d * 0.18).
    expect(dpadCenterRadius(100), 28);
    expect(dpadCenterRadius(300), 54);
    expect(
      dpadRegionAt(const Offset(150 + 53, 150), const Size(300, 300)),
      DpadRegion.center,
    );
    expect(
      dpadRegionAt(const Offset(150 + 55, 150), const Size(300, 300)),
      DpadRegion.right,
    );
  });

  test('dpad_key_codes', () {
    expect(
      [for (final r in DpadRegion.values) dpadKeyCode(r)],
      [
        KeyCodes.dpadUp,
        KeyCodes.dpadDown,
        KeyCodes.dpadLeft,
        KeyCodes.dpadRight,
        KeyCodes.dpadCenter,
      ],
    );
  });

  testWidgets('center_button_is_56dp_minimum', (t) async {
    final handle = t.ensureSemantics();
    await pumpPad(t, side: 160);
    final rect = find.semantics.byLabel('OK').evaluate().single.rect;
    expect(rect.width, greaterThanOrEqualTo(56));
    expect(rect.height, greaterThanOrEqualTo(56));
    handle.dispose();
  });

  testWidgets('tapping_each_region_sends_its_key', (t) async {
    await pumpPad(t);
    for (final offset in const [up, down, left, right, Offset.zero]) {
      await t.tapAt(centre(t) + offset);
      await t.pump();
    }
    expect(rec.calls, [
      'tap:${KeyCodes.dpadUp}',
      'tap:${KeyCodes.dpadDown}',
      'tap:${KeyCodes.dpadLeft}',
      'tap:${KeyCodes.dpadRight}',
      'tap:${KeyCodes.dpadCenter}',
    ]);
  });

  testWidgets('a_tap_sends_the_region_that_was_tinted_at_pointer_down', (
    t,
  ) async {
    await pumpPad(t);
    // 5 dp on the Up side of the Up/Right diagonal...
    final g = await t.startGesture(centre(t) + const Offset(70, -75));
    await t.pump();
    // ...released 10 dp further right, on the Right side (within tap slop).
    await g.moveTo(centre(t) + const Offset(80, -75));
    await g.up();
    await t.pump();
    expect(rec.calls, ['tap:${KeyCodes.dpadUp}']);
  });

  testWidgets('holding_a_direction_holds_its_key', (t) async {
    await pumpPad(t);
    final g = await t.startGesture(centre(t) + up);
    await t.pump(kHoldThreshold);
    expect(rec.calls, ['holdStart:${KeyCodes.dpadUp}']);
    await g.up();
    expect(rec.calls, [
      'holdStart:${KeyCodes.dpadUp}',
      'holdEnd:${KeyCodes.dpadUp}',
    ]);
  });

  testWidgets('holding_the_center_holds_ok', (t) async {
    await pumpPad(t);
    final g = await t.startGesture(centre(t));
    await t.pump(kHoldThreshold);
    await g.up();
    expect(rec.calls, [
      'holdStart:${KeyCodes.dpadCenter}',
      'holdEnd:${KeyCodes.dpadCenter}',
    ]);
  });

  testWidgets('a_press_shorter_than_the_threshold_is_a_tap', (t) async {
    await pumpPad(t);
    final g = await t.startGesture(centre(t) + right);
    await t.pump(kHoldThreshold - const Duration(milliseconds: 50));
    await g.up();
    await t.pump(kHoldThreshold);
    expect(rec.calls, ['tap:${KeyCodes.dpadRight}']);
  });

  testWidgets('a_cancelled_hold_still_ends', (t) async {
    await pumpPad(t);
    final g = await t.startGesture(centre(t) + left);
    await t.pump(kHoldThreshold);
    await g.cancel();
    expect(rec.calls, [
      'holdStart:${KeyCodes.dpadLeft}',
      'holdEnd:${KeyCodes.dpadLeft}',
    ]);
  });

  testWidgets('removing_a_held_pad_ends_the_hold_once', (t) async {
    await pumpPad(t);
    final g = await t.startGesture(centre(t) + down);
    await t.pump(kHoldThreshold);
    await t.pumpWidget(const SizedBox());
    expect(rec.calls, [
      'holdStart:${KeyCodes.dpadDown}',
      'holdEnd:${KeyCodes.dpadDown}',
    ]);
    await g.up();
    expect(rec.calls, hasLength(2));
  });

  testWidgets('press_outside_the_circle_does_nothing', (t) async {
    await pumpPad(t);
    final corner = t.getTopLeft(find.byType(Dpad)) + const Offset(4, 4);
    await t.tapAt(corner);
    await t.pump();
    final g = await t.startGesture(corner);
    await t.pump(kHoldThreshold * 2);
    await g.up();
    expect(rec.calls, isEmpty);
  });

  testWidgets('dpad_semantics_has_five_labelled_buttons', (t) async {
    final handle = t.ensureSemantics();
    await pumpPad(t);
    const expected = {
      'Up': KeyCodes.dpadUp,
      'Down': KeyCodes.dpadDown,
      'Left': KeyCodes.dpadLeft,
      'Right': KeyCodes.dpadRight,
      'OK': KeyCodes.dpadCenter,
    };
    for (final label in expected.keys) {
      final node = find.semantics.byLabel(label);
      expect(node.evaluate(), hasLength(1), reason: label);
      expect(
        node.evaluate().single,
        isSemantics(
          label: label,
          isButton: true,
          hasTapAction: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
        reason: label,
      );
    }
    t.semantics.tap(find.semantics.byLabel('OK'));
    await t.pump();
    expect(rec.calls, ['tap:${KeyCodes.dpadCenter}']);
    t.semantics.tap(find.semantics.byLabel('Left'));
    await t.pump();
    expect(rec.calls.last, 'tap:${KeyCodes.dpadLeft}');
    handle.dispose();
  });

  testWidgets('screen_reader_order_is_up_left_ok_right_down', (t) async {
    final handle = t.ensureSemantics();
    try {
      await pumpPad(t);
      final pad = find.semantics.byLabel('Up').evaluate().single.parent!;
      expect(
        [
          for (final node in pad.debugListChildrenInOrder(
            DebugSemanticsDumpOrder.traversalOrder,
          ))
            node.label,
        ],
        ['Up', 'Left', 'OK', 'Right', 'Down'],
      );
    } finally {
      handle.dispose();
    }
  });

  testWidgets('pad_is_clamped_between_160_and_320', (t) async {
    await pumpApp(
      t,
      SizedBox(width: 600, height: 500, child: Dpad(input: rec)),
    );
    expect(t.getSize(find.byType(CustomPaint).last), const Size(320, 320));
    await pumpApp(
      t,
      SizedBox(width: 100, height: 100, child: Dpad(input: rec)),
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('dpad_and_numpad_fit_320dp_at_200_percent_text', (t) async {
    await pumpApp(
      t,
      SizedBox(width: 288, height: 200, child: Dpad(input: rec)),
      textScale: 2,
    );
    expect(t.takeException(), isNull);
    expect(t.getSize(find.byType(CustomPaint).last), const Size(200, 200));
  });

  testWidgets('reduce_motion_does_not_change_the_pad', (t) async {
    await pumpPad(t, disableAnimations: true);
    await t.tapAt(centre(t) + up);
    await t.pump();
    expect(rec.calls, ['tap:${KeyCodes.dpadUp}']);
  });

  /// The region the pad tints now.
  DpadRegion? tinted(WidgetTester t) {
    final paint = t.widget<CustomPaint>(
      find.descendant(
        of: find.byType(Dpad),
        matching: find.byType(CustomPaint),
      ),
    );
    return dpadTintedRegion(paint.painter);
  }

  testWidgets('hold_starts_on_the_region_the_finger_went_down_on', (t) async {
    // A pin against a "where the finger is now" design; it passes without
    // the _downRegion fix too. The regression test for that fix is
    // a_hold_keeps_its_down_region_when_the_pad_resizes, below.
    await pumpPad(t);
    // 8 dp outside the 54 dp OK disc of a 300 dp pad: Up.
    final g = await t.startGesture(centre(t) + const Offset(0, -62));
    await t.pump(const Duration(milliseconds: 100));
    // A drift into the OK disc before the threshold. It stays under the
    // 18 dp touch slop (a 20 dp drift would cancel the hold altogether).
    await g.moveBy(const Offset(0, 15));
    await t.pump(kHoldThreshold);
    expect(rec.calls, ['holdStart:${KeyCodes.dpadUp}']);
    await g.up();
    expect(rec.calls.last, 'holdEnd:${KeyCodes.dpadUp}');
  });

  testWidgets('a_hold_keeps_its_down_region_when_the_pad_resizes', (t) async {
    // The pad can change size under a finger: the quick row or the preview
    // card coming and going changes the room the remote gives it.
    final side = ValueNotifier<double>(300);
    addTearDown(side.dispose);
    await pumpApp(
      t,
      ValueListenableBuilder<double>(
        valueListenable: side,
        builder: (_, s, _) => SizedBox.square(
          dimension: s,
          child: Dpad(input: rec),
        ),
      ),
    );
    final g = await t.startGesture(centre(t) + const Offset(0, -62));
    await t.pump();
    expect(tinted(t), DpadRegion.up);
    // On a 160 dp pad the same spot of the old box lies in the Right wedge.
    side.value = 160;
    await t.pump(const Duration(milliseconds: 100));
    expect(rec.calls, isEmpty, reason: 'resized before the hold starts');
    await t.pump(kHoldThreshold);
    expect(rec.calls, ['holdStart:${KeyCodes.dpadUp}']);
    await g.up();
    expect(rec.calls, [
      'holdStart:${KeyCodes.dpadUp}',
      'holdEnd:${KeyCodes.dpadUp}',
    ]);
  });

  // RemoteBody never gives the pad less than 160 dp; this is the floor the
  // pad itself clamps to. At 100 dp the OK disc keeps 56 dp and each wedge is
  // at least 48 dp across its middle, but only about 22 dp deep: below
  // 160 dp the wedges are not full 48 dp touch targets.
  testWidgets('dpad_clamps_to_100x100_with_wide_but_shallow_wedges', (
    t,
  ) async {
    await pumpPad(t, side: 100);
    expect(t.takeException(), isNull);
    final size = t.getSize(
      find.descendant(
        of: find.byType(Dpad),
        matching: find.byType(CustomPaint),
      ),
    );
    expect(size, const Size(100, 100));

    // The OK disc keeps its 56 dp; each wedge is at least 48 dp across its
    // middle, where its tap lands (measured along that chord only).
    const radius = 50.0;
    final okRadius = dpadCenterRadius(100);
    expect(okRadius * 2, greaterThanOrEqualTo(56));
    // The depth from the OK disc to the edge: what the name calls shallow.
    expect(radius - okRadius, 22);
    final mid = (okRadius + radius) / 2;
    for (final (region, along, across) in const [
      (DpadRegion.up, Offset(0, -1), Offset(1, 0)),
      (DpadRegion.down, Offset(0, 1), Offset(1, 0)),
      (DpadRegion.left, Offset(-1, 0), Offset(0, 1)),
      (DpadRegion.right, Offset(1, 0), Offset(0, 1)),
    ]) {
      var span = 0;
      for (var d = -50; d <= 50; d++) {
        final p = const Offset(50, 50) + along * mid + across * d.toDouble();
        if (dpadRegionAt(p, size) == region) span++;
      }
      expect(span, greaterThanOrEqualTo(48), reason: '$region');
    }

    // And a tap on each region reaches it.
    for (final offset in [
      Offset(0, -mid),
      Offset(0, mid),
      Offset(-mid, 0),
      Offset(mid, 0),
      Offset.zero,
    ]) {
      await t.tapAt(centre(t) + offset);
      await t.pump();
    }
    expect(rec.calls, [
      'tap:${KeyCodes.dpadUp}',
      'tap:${KeyCodes.dpadDown}',
      'tap:${KeyCodes.dpadLeft}',
      'tap:${KeyCodes.dpadRight}',
      'tap:${KeyCodes.dpadCenter}',
    ]);
  });

  testWidgets('dragging_across_wedges_keeps_the_first_region', (t) async {
    await pumpPad(t);
    final g = await t.startGesture(centre(t) + up);
    await t.pump();
    expect(tinted(t), DpadRegion.up);
    // Across the Up/Right diagonal and deep into the Right wedge.
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(12, 8));
      await t.pump(const Duration(milliseconds: 10));
    }
    expect(tinted(t), DpadRegion.up);
    await g.up();
    await t.pump();
    expect(tinted(t), isNull);
    // A drag is not a tap: nothing is sent, and never the Right key.
    expect(rec.calls, isEmpty);
  });

  testWidgets('a_hold_stays_on_its_region_while_dragging', (t) async {
    await pumpPad(t);
    final g = await t.startGesture(centre(t) + up);
    await t.pump(kHoldThreshold);
    expect(rec.calls, ['holdStart:${KeyCodes.dpadUp}']);
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(12, 8));
      await t.pump(const Duration(milliseconds: 10));
    }
    expect(tinted(t), DpadRegion.up);
    expect(rec.calls, ['holdStart:${KeyCodes.dpadUp}']);
    await g.up();
    expect(rec.calls, [
      'holdStart:${KeyCodes.dpadUp}',
      'holdEnd:${KeyCodes.dpadUp}',
    ]);
  });
}
