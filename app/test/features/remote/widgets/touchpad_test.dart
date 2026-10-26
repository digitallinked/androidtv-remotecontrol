import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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

  testWidgets('touchpad_exposes_semantic_actions', (t) async {
    final handle = t.ensureSemantics();
    await pumpPad(t);
    final node = t.getSemantics(find.byType(Touchpad));
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
      // hint) and the test font is Ahem, one em per glyph, so how many lines
      // it takes here says nothing about a real font.
      expect(find.text('Swipe to move · Tap to select'), findsOneWidget);
    }
  });
}
