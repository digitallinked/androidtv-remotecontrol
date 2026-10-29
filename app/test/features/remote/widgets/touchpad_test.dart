import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/features/remote/presentation/widgets/touchpad.dart';

import '../../../helpers/key_input_recorder.dart';
import '../../../helpers/pump_app.dart';

void main() {
  late KeyInputRecorder rec;

  setUp(() => rec = KeyInputRecorder());

  Future<void> pumpPad(
    WidgetTester t, {
    double textScale = 1,
    bool disableAnimations = false,
    Brightness brightness = Brightness.light,
  }) => pumpApp(
    t,
    SizedBox(width: 320, height: 320, child: Touchpad(input: rec)),
    textScale: textScale,
    disableAnimations: disableAnimations,
    brightness: brightness,
  );

  Offset centre(WidgetTester t) => t.getCenter(find.byType(Touchpad));

  testWidgets('swipe_right_sends_dpad_right', (t) async {
    await pumpPad(t);
    final g = await t.startGesture(centre(t));
    await g.moveBy(const Offset(30, 2));
    await g.up();
    expect(rec.calls, ['tap:${KeyCodes.dpadRight}']);
  });

  testWidgets('long_drag_sends_multiple_steps', (t) async {
    await pumpPad(t);
    final g = await t.startGesture(centre(t) - const Offset(80, 0));
    await g.moveBy(const Offset(24 + 40 * 3, 0)); // a single move event
    await g.up();
    expect(rec.calls, List.filled(4, 'tap:${KeyCodes.dpadRight}'));
  });

  testWidgets('tap_sends_center', (t) async {
    await pumpPad(t);
    await t.tap(find.byType(Touchpad));
    await t.pump();
    expect(rec.calls, ['tap:${KeyCodes.dpadCenter}']);
  });

  testWidgets('two_finger_tap_sends_back', (t) async {
    await pumpPad(t);
    final g1 = await t.startGesture(centre(t) - const Offset(30, 0));
    final g2 = await t.startGesture(centre(t) + const Offset(30, 0));
    await t.pump(const Duration(milliseconds: 50));
    await g1.up();
    await g2.up();
    expect(rec.calls, ['tap:${KeyCodes.back}']);
    expect(rec.calls, isNot(contains('tap:${KeyCodes.dpadCenter}')));
  });

  testWidgets('two_finger_touch_held_past_400ms_is_not_back', (t) async {
    await pumpPad(t);
    final g1 = await t.startGesture(centre(t) - const Offset(30, 0));
    final g2 = await t.startGesture(centre(t) + const Offset(30, 0));
    await t.pump(const Duration(milliseconds: 450));
    await g1.up();
    await g2.up();
    expect(rec.calls, isEmpty);
  });

  testWidgets('two_fingers_that_move_24dp_are_not_back', (t) async {
    await pumpPad(t);
    final g1 = await t.startGesture(centre(t) - const Offset(30, 0));
    final g2 = await t.startGesture(centre(t) + const Offset(30, 0));
    await g2.moveBy(const Offset(0, 30));
    await g1.up();
    await g2.up();
    expect(rec.calls, isEmpty);
  });

  testWidgets('three_fingers_do_nothing', (t) async {
    await pumpPad(t);
    final gs = [
      await t.startGesture(centre(t) - const Offset(40, 0)),
      await t.startGesture(centre(t)),
      await t.startGesture(centre(t) + const Offset(40, 0)),
    ];
    for (final g in gs) {
      await g.up();
    }
    await t.pump(kLongPressTimeout);
    expect(rec.calls, isEmpty);
  });

  testWidgets('small_jitter_sends_nothing', (t) async {
    await pumpPad(t);
    final g = await t.startGesture(centre(t));
    await g.moveBy(const Offset(20, 0));
    await g.up();
    await t.pump(kLongPressTimeout);
    expect(rec.calls, isEmpty);
  });

  testWidgets('jitter_under_the_touch_slop_still_taps', (t) async {
    await pumpPad(t);
    final g = await t.startGesture(centre(t));
    await g.moveBy(const Offset(10, 5));
    await g.up();
    expect(rec.calls, ['tap:${KeyCodes.dpadCenter}']);
  });

  testWidgets('long_press_holds_center', (t) async {
    await pumpPad(t);
    final g = await t.startGesture(centre(t));
    await t.pump(kLongPressTimeout);
    expect(rec.calls, ['holdStart:${KeyCodes.dpadCenter}']);
    await g.up();
    expect(rec.calls, [
      'holdStart:${KeyCodes.dpadCenter}',
      'holdEnd:${KeyCodes.dpadCenter}',
    ]);
  });

  testWidgets('movement_after_the_hold_starts_is_ignored', (t) async {
    await pumpPad(t);
    final g = await t.startGesture(centre(t));
    await t.pump(kLongPressTimeout);
    await g.moveBy(const Offset(100, 0));
    await g.up();
    expect(rec.calls, [
      'holdStart:${KeyCodes.dpadCenter}',
      'holdEnd:${KeyCodes.dpadCenter}',
    ]);
  });

  testWidgets('moving_past_the_slop_cancels_the_hold', (t) async {
    await pumpPad(t);
    final g = await t.startGesture(centre(t));
    await g.moveBy(const Offset(20, 0));
    await t.pump(kLongPressTimeout * 2);
    await g.up();
    expect(rec.calls, isEmpty);
  });

  testWidgets('vertical_swipe_up_sends_dpad_up', (t) async {
    await pumpPad(t);
    final g = await t.startGesture(centre(t));
    await g.moveBy(const Offset(3, -30));
    await g.up();
    expect(rec.calls, ['tap:${KeyCodes.dpadUp}']);
  });

  testWidgets('swipes_left_and_down_send_their_keys', (t) async {
    await pumpPad(t);
    final left = await t.startGesture(centre(t));
    await left.moveBy(const Offset(-30, 0));
    await left.up();
    final down = await t.startGesture(centre(t));
    await down.moveBy(const Offset(0, 30));
    await down.up();
    expect(rec.calls, ['tap:${KeyCodes.dpadLeft}', 'tap:${KeyCodes.dpadDown}']);
  });

  testWidgets('a_slow_drag_steps_24_then_every_40dp', (t) async {
    await pumpPad(t);
    final g = await t.startGesture(centre(t));
    for (var i = 0; i < 12; i++) {
      await g.moveBy(const Offset(10, 0)); // 120 dp in total
    }
    await g.up();
    // 24, then 64, 104 (the next, 144, is out of reach).
    expect(rec.calls, List.filled(3, 'tap:${KeyCodes.dpadRight}'));
  });

  testWidgets('direction_follows_the_dominant_axis_after_a_turn', (t) async {
    await pumpPad(t);
    final g = await t.startGesture(centre(t));
    await g.moveBy(const Offset(30, 0));
    await g.moveBy(const Offset(0, 45));
    await g.up();
    expect(rec.calls, [
      'tap:${KeyCodes.dpadRight}',
      'tap:${KeyCodes.dpadDown}',
    ]);
  });

  testWidgets('second_finger_after_a_step_is_ignored', (t) async {
    await pumpPad(t);
    final g1 = await t.startGesture(centre(t));
    await g1.moveBy(const Offset(30, 0));
    final g2 = await t.startGesture(centre(t) + const Offset(0, 60));
    await g2.up();
    await g1.up();
    expect(rec.calls, ['tap:${KeyCodes.dpadRight}']);
  });

  testWidgets('pointer_cancel_ends_a_hold', (t) async {
    await pumpPad(t);
    final g = await t.startGesture(centre(t));
    await t.pump(kLongPressTimeout);
    await g.cancel();
    await t.pump();
    expect(rec.calls, [
      'holdStart:${KeyCodes.dpadCenter}',
      'holdEnd:${KeyCodes.dpadCenter}',
    ]);
  });

  testWidgets('pointer_cancel_without_a_hold_sends_nothing', (t) async {
    await pumpPad(t);
    final g = await t.startGesture(centre(t));
    await g.cancel();
    await t.pump(kLongPressTimeout);
    expect(rec.calls, isEmpty);
  });

  testWidgets('removing_the_pad_mid_hold_ends_the_hold_once', (t) async {
    await pumpPad(t);
    final g = await t.startGesture(centre(t));
    await t.pump(kLongPressTimeout);
    await t.pumpWidget(const SizedBox());
    await g.up();
    expect(rec.calls, [
      'holdStart:${KeyCodes.dpadCenter}',
      'holdEnd:${KeyCodes.dpadCenter}',
    ]);
  });

  testWidgets('touchpad_wins_against_an_ancestor_scrollable', (t) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await pumpApp(
      t,
      ListView(
        controller: controller,
        children: [
          SizedBox(height: 320, child: Touchpad(input: rec)),
          const SizedBox(height: 1200),
        ],
      ),
    );
    final g = await t.startGesture(centre(t));
    await g.moveBy(const Offset(0, -100));
    await g.up();
    await t.pump();
    expect(controller.offset, 0);
    expect(rec.calls, ['tap:${KeyCodes.dpadUp}', 'tap:${KeyCodes.dpadUp}']);
  });

  testWidgets('second_finger_mid_hold_is_ignored_and_the_hold_ends_once', (
    t,
  ) async {
    await pumpPad(t);
    final g1 = await t.startGesture(centre(t));
    await t.pump(kLongPressTimeout);
    final g2 = await t.startGesture(centre(t) + const Offset(0, 60));
    await g2.up();
    expect(rec.calls, ['holdStart:${KeyCodes.dpadCenter}']);
    await g1.up();
    expect(rec.calls, [
      'holdStart:${KeyCodes.dpadCenter}',
      'holdEnd:${KeyCodes.dpadCenter}',
    ]);
  });

  testWidgets('second_finger_after_a_dead_zone_move_sends_nothing', (t) async {
    await pumpPad(t);
    final g1 = await t.startGesture(centre(t) - const Offset(30, 0));
    await g1.moveBy(const Offset(20, 0)); // past the touch slop, no step
    final g2 = await t.startGesture(centre(t) + const Offset(30, 0));
    await g1.up();
    await g2.up();
    expect(rec.calls, isEmpty);
  });

  testWidgets('trail_follows_only_the_first_finger', (t) async {
    await pumpPad(t);
    final g1 = await t.startGesture(centre(t) - const Offset(30, 0));
    final g2 = await t.startGesture(centre(t) + const Offset(30, 0));
    await g2.moveBy(const Offset(0, 5));
    await g2.moveBy(const Offset(0, 5));
    await t.pump();
    expect(find.byKey(Touchpad.trailKey), paintsNothing);
    await g1.up();
    await g2.up();
  });

  testWidgets('trail_forgets_old_points_after_an_idle_pause', (t) async {
    await pumpPad(t);
    final first = await t.startGesture(centre(t) - const Offset(100, 0));
    await first.moveBy(const Offset(10, 0));
    await first.up();
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    final start = centre(t) + const Offset(0, -60);
    final second = await t.startGesture(start);
    final downPoint = t.getTopLeft(find.byType(Touchpad)) + Offset.zero;
    final local = start - downPoint;
    for (var i = 0; i < 12; i++) {
      await second.moveBy(const Offset(1, 0));
      await t.pump(const Duration(milliseconds: 40));
    }
    // 480 ms after the touch went down its point is no longer part of the
    // trail, so no segment starts at it.
    expect(find.byKey(Touchpad.trailKey), paints..line());
    expect(
      find.byKey(Touchpad.trailKey),
      paints..everything((method, args) {
        if (method != #drawLine) return true;
        return ((args[0] as Offset) - local).distance > 0.01;
      }),
    );
    await second.up();
  });

  testWidgets('edge_glow_fades_in_200ms_even_after_an_idle_pause', (t) async {
    await pumpPad(t);
    final first = await t.startGesture(centre(t));
    await first.moveBy(const Offset(30, 0));
    await first.up();
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(Touchpad.trailKey), paintsNothing);

    final second = await t.startGesture(centre(t));
    await second.moveBy(const Offset(30, 0));
    await second.up();
    await t.pump();
    expect(find.byKey(Touchpad.trailKey), paints..rect());
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byKey(Touchpad.trailKey), paintsNothing);
  });

  testWidgets('touchpad_needs_bounded_constraints', (t) async {
    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SingleChildScrollView(child: Touchpad(input: rec)),
      ),
    );
    expect(t.takeException(), isA<AssertionError>());
  });

  testWidgets('touchpad_exposes_semantic_actions', (t) async {
    final handle = t.ensureSemantics();
    await pumpPad(t);
    final node = t.getSemantics(find.bySemanticsLabel('Touchpad'));
    final data = node.getSemanticsData();
    expect(data.label, 'Touchpad');
    expect(data.hint, contains('Swipe to move'));
    expect(data.hasAction(SemanticsAction.tap), isTrue);

    final owner = node.owner!;
    CustomSemanticsAction named(String label) => data.customSemanticsActionIds!
        .map(CustomSemanticsAction.getAction)
        .whereType<CustomSemanticsAction>()
        .firstWhere((a) => a.label == label);

    for (final (label, code) in [
      ('Up', KeyCodes.dpadUp),
      ('Down', KeyCodes.dpadDown),
      ('Left', KeyCodes.dpadLeft),
      ('Right', KeyCodes.dpadRight),
      ('Back', KeyCodes.back),
    ]) {
      owner.performAction(
        node.id,
        SemanticsAction.customAction,
        CustomSemanticsAction.getIdentifier(named(label)),
      );
      expect(rec.calls.last, 'tap:$code');
    }
    owner.performAction(node.id, SemanticsAction.tap);
    expect(rec.calls.last, 'tap:${KeyCodes.dpadCenter}');
    expect(rec.calls, hasLength(6));
    handle.dispose();
  });

  testWidgets('touchpad_paints_a_trail_while_swiping', (t) async {
    await pumpPad(t);
    final g = await t.startGesture(centre(t));
    await g.moveBy(const Offset(10, 0));
    await g.moveBy(const Offset(10, 0));
    await t.pump();
    expect(find.byKey(Touchpad.trailKey), paints..line());
    await g.up();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byKey(Touchpad.trailKey), paintsNothing);
  });

  testWidgets('reduce_motion_paints_no_trail', (t) async {
    await pumpPad(t, disableAnimations: true);
    final g = await t.startGesture(centre(t));
    await g.moveBy(const Offset(30, 0));
    await g.moveBy(const Offset(10, 0));
    await t.pump();
    expect(find.byKey(Touchpad.trailKey), paintsNothing);
    await g.up();
    expect(rec.calls, ['tap:${KeyCodes.dpadRight}']);
  });

  testWidgets('touchpad_fits_320dp_at_200_percent_text', (t) async {
    t.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    for (final b in Brightness.values) {
      await pumpPad(t, textScale: 2, brightness: b);
      expect(t.takeException(), isNull);
      expect(t.getSize(find.byType(Touchpad)), const Size(320, 320));
      // The idle hint is decorative (the semantics node carries the full
      // hint). The test font is Ahem, one em per glyph, so the cap binds here
      // where a real font would fit: this proves the cap is 2 lines and the
      // text ends in an ellipsis rather than overflowing.
      final hint = find.text('Swipe to move · Tap to select');
      expect(hint, findsOneWidget);
      final text = t.widget<Text>(hint);
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(t.renderObject<RenderParagraph>(hint).didExceedMaxLines, isTrue);
    }
  });

  /// The rings the pad paints now, as (centre, radius, alpha).
  List<(Offset, double, double)> rings(WidgetTester t) {
    final found = <(Offset, double, double)>[];
    expect(
      find.byKey(Touchpad.trailKey),
      paints..everything((method, args) {
        if (method == #drawCircle) {
          final paint = args[2] as Paint;
          expect(paint.style, PaintingStyle.stroke);
          found.add((args[0] as Offset, args[1] as double, paint.color.a));
        }
        return true;
      }),
    );
    return found;
  }

  testWidgets('tap_paints_a_pulse_that_fades_in_200ms', (t) async {
    await pumpPad(t);
    final origin = t.getTopLeft(find.byType(Touchpad));
    const local = Offset(100, 140);
    await t.tapAt(origin + local);
    await t.pump();
    expect(rec.calls, ['tap:${KeyCodes.dpadCenter}']);
    var now = rings(t);
    expect(now, hasLength(1));
    expect(now.single.$1, local);
    expect(now.single.$2, lessThan(1));
    expect(now.single.$3, closeTo(0.35, 0.01));
    expect(t.hasRunningAnimations, isTrue);

    await t.pump(const Duration(milliseconds: 100));
    now = rings(t);
    expect(now, hasLength(1));
    expect(now.single.$1, local);
    expect(now.single.$2, inExclusiveRange(1, 24));
    expect(now.single.$3, inExclusiveRange(0, 0.35));

    await t.pump(const Duration(milliseconds: 110));
    expect(find.byKey(Touchpad.trailKey), paintsNothing);
    // The tap's trail point outlives the pulse by 50 ms; then all is still.
    await t.pump(const Duration(milliseconds: 50));
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets('two_finger_back_paints_a_pulse', (t) async {
    await pumpPad(t);
    final g1 = await t.startGesture(centre(t) - const Offset(30, 0));
    final g2 = await t.startGesture(centre(t) + const Offset(30, 0));
    await t.pump(const Duration(milliseconds: 50));
    await g1.up();
    await g2.up();
    await t.pump();
    expect(rec.calls, ['tap:${KeyCodes.back}']);
    expect(rings(t), hasLength(1));
  });

  testWidgets('a_swipe_paints_no_pulse', (t) async {
    await pumpPad(t);
    final g = await t.startGesture(centre(t));
    await g.moveBy(const Offset(30, 0));
    await g.up();
    await t.pump();
    expect(rec.calls, ['tap:${KeyCodes.dpadRight}']);
    expect(rings(t), isEmpty);
  });

  testWidgets('reduce_motion_paints_no_pulse', (t) async {
    await pumpPad(t, disableAnimations: true);
    await t.tap(find.byType(Touchpad));
    await t.pump();
    expect(rec.calls, ['tap:${KeyCodes.dpadCenter}']);
    expect(find.byKey(Touchpad.trailKey), paintsNothing);
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets('a_flick_past_the_slop_between_move_and_up_is_not_a_tap', (
    t,
  ) async {
    await pumpPad(t);
    final origin = t.getTopLeft(find.byType(Touchpad));
    final pointer = TestPointer(7);
    t.binding.handlePointerEvent(pointer.down(origin + const Offset(100, 100)));
    t.binding.handlePointerEvent(
      pointer.move(origin + const Offset(102, 100)),
    );
    // The finger lifts past the slop, with no move event in between.
    t.binding.handlePointerEvent(
      PointerUpEvent(
        pointer: 7,
        position: origin + const Offset(100 + kTouchSlop + 4, 100),
      ),
    );
    await t.pump(kLongPressTimeout);
    expect(rec.calls, isEmpty);
  });

  testWidgets('a_tap_whose_up_stays_inside_the_slop_still_taps', (t) async {
    await pumpPad(t);
    final origin = t.getTopLeft(find.byType(Touchpad));
    final pointer = TestPointer(8);
    t.binding.handlePointerEvent(pointer.down(origin + const Offset(100, 100)));
    t.binding.handlePointerEvent(
      PointerUpEvent(
        pointer: 8,
        position: origin + const Offset(100 + kTouchSlop - 4, 100),
      ),
    );
    await t.pump();
    expect(rec.calls, ['tap:${KeyCodes.dpadCenter}']);
  });
}
