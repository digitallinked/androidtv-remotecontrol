import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/widgets/app_key_button.dart';

import '../../helpers/pump_app.dart';

Widget key({
  VoidCallback? onTap,
  VoidCallback? start,
  VoidCallback? end,
  VoidCallback? semanticLongPress,
  Color? color,
  Duration d = kLongPressTimeout,
}) => AppKeyButton(
  semanticLabel: 'Volume up',
  icon: const Icon(Icons.add),
  onTap: onTap ?? () {},
  onLongPressStart: start,
  onLongPressEnd: end,
  onSemanticLongPress: semanticLongPress,
  color: color,
  longPressDuration: d,
);

void main() {
  testWidgets('key_button_min_size_56dp', (t) async {
    await pumpApp(
      t,
      AppKeyButton(
        semanticLabel: 'x',
        icon: const SizedBox(width: 4, height: 4),
        onTap: () {},
      ),
    );
    final s = t.getSize(find.byType(AppKeyButton));
    expect(s, const Size(56, 56));
  });

  testWidgets('tap_calls_onTap_once', (t) async {
    var n = 0;
    await pumpApp(t, key(onTap: () => n++));
    await t.tap(find.byType(AppKeyButton));
    await t.pumpAndSettle();
    expect(n, 1);
  });

  testWidgets('long_press_calls_start_then_end_and_not_tap', (t) async {
    final log = <String>[];
    await pumpApp(
      t,
      key(
        onTap: () => log.add('tap'),
        start: () => log.add('start'),
        end: () => log.add('end'),
      ),
    );
    await t.longPress(find.byType(AppKeyButton));
    await t.pumpAndSettle();
    expect(log, ['start', 'end']);
  });

  testWidgets('long_press_end_fires_once_when_pointer_cancelled', (t) async {
    final log = <String>[];
    await pumpApp(
      t,
      key(start: () => log.add('start'), end: () => log.add('end')),
    );
    final g = await t.startGesture(t.getCenter(find.byType(AppKeyButton)));
    await t.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await g.cancel();
    await t.pumpAndSettle();
    expect(log, ['start', 'end']);
  });

  testWidgets('dispose_during_hold_calls_end_once', (t) async {
    final log = <String>[];
    await pumpApp(
      t,
      key(start: () => log.add('start'), end: () => log.add('end')),
    );
    final g = await t.startGesture(t.getCenter(find.byType(AppKeyButton)));
    await t.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await pumpApp(t, const SizedBox());
    await g.up();
    await t.pumpAndSettle();
    expect(log, ['start', 'end']);
  });

  testWidgets('custom_long_press_duration_respected', (t) async {
    var starts = 0;
    await pumpApp(
      t,
      key(
        start: () => starts++,
        end: () {},
        d: const Duration(milliseconds: 600),
      ),
    );
    final g = await t.startGesture(t.getCenter(find.byType(AppKeyButton)));
    await t.pump(const Duration(milliseconds: 550));
    expect(starts, 0);
    await t.pump(const Duration(milliseconds: 100));
    expect(starts, 1);
    await g.up();
  });

  testWidgets('semantics_label_and_long_press_action', (t) async {
    final h = t.ensureSemantics();
    await pumpApp(t, key(start: () {}, end: () {}));
    expect(find.bySemanticsLabel('Volume up'), findsOneWidget);
    expect(
      t
          .getSemantics(find.bySemanticsLabel('Volume up'))
          .getSemanticsData()
          .hasAction(SemanticsAction.longPress),
      isTrue,
    );
    h.dispose();
  });

  testWidgets('semantic_long_press_defaults_to_one_tap', (t) async {
    final h = t.ensureSemantics();
    var taps = 0;
    var starts = 0;
    var ends = 0;
    await pumpApp(
      t,
      key(onTap: () => taps++, start: () => starts++, end: () => ends++),
    );
    t.semantics.longPress(find.semantics.byLabel('Volume up'));
    await t.pumpAndSettle();
    expect((taps, starts, ends), (1, 0, 0));
    h.dispose();
  });

  testWidgets('semantic_long_press_uses_the_override', (t) async {
    final h = t.ensureSemantics();
    var taps = 0;
    var overrides = 0;
    var starts = 0;
    var ends = 0;
    await pumpApp(
      t,
      key(
        onTap: () => taps++,
        start: () => starts++,
        end: () => ends++,
        semanticLongPress: () => overrides++,
      ),
    );
    t.semantics.longPress(find.semantics.byLabel('Volume up'));
    await t.pumpAndSettle();
    expect((taps, overrides, starts, ends), (0, 1, 0, 0));
    h.dispose();
  });

  testWidgets('semantic_long_press_override_alone_offers_the_action', (
    t,
  ) async {
    final h = t.ensureSemantics();
    var overrides = 0;
    await pumpApp(t, key(semanticLongPress: () => overrides++));
    t.semantics.longPress(find.semantics.byLabel('Volume up'));
    await t.pumpAndSettle();
    expect(overrides, 1);
    h.dispose();
  });

  testWidgets('no_semantic_long_press_without_hold_callbacks', (t) async {
    final h = t.ensureSemantics();
    await pumpApp(t, key());
    final data = t
        .getSemantics(find.bySemanticsLabel('Volume up'))
        .getSemanticsData();
    expect(data.hasAction(SemanticsAction.longPress), isFalse);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    h.dispose();
  });

  testWidgets('removing_a_held_key_ends_the_hold_once', (t) async {
    var starts = 0;
    var ends = 0;
    await pumpApp(t, key(start: () => starts++, end: () => ends++));
    final g = await t.startGesture(t.getCenter(find.byType(AppKeyButton)));
    await t.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect((starts, ends), (1, 0));
    await pumpApp(t, const SizedBox());
    expect((starts, ends), (1, 1));
    await g.up();
    await t.pumpAndSettle();
    expect((starts, ends), (1, 1));
  });

  testWidgets('key_colour_override_is_painted', (t) async {
    Color? fill() => t
        .widget<Material>(
          find.descendant(
            of: find.byType(AppKeyButton),
            matching: find.byType(Material),
          ),
        )
        .color;
    await pumpApp(t, key());
    final raised = fill();
    expect(raised, isNot(Colors.transparent));
    await pumpApp(t, key(color: Colors.transparent));
    expect(fill(), Colors.transparent);
  });

  testWidgets('transparent_key_still_shows_press_scale', (t) async {
    await pumpApp(t, key(color: Colors.transparent));
    final g = await t.startGesture(t.getCenter(find.byType(AppKeyButton)));
    await t.pump(const Duration(milliseconds: 300));
    expect(
      t.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      lessThan(1),
    );
    await g.up();
  });

  testWidgets('press_scale_has_no_animation_with_reduce_motion', (t) async {
    await pumpApp(t, key(), disableAnimations: true);
    expect(
      t.widget<AnimatedScale>(find.byType(AnimatedScale)).duration,
      Duration.zero,
    );
  });

  testWidgets('second_press_ripple_is_not_stuck_after_first_fades_out', (
    t,
  ) async {
    await pumpApp(t, key());
    final centre = t.getCenter(find.byType(AppKeyButton));
    await t.tapAt(centre);
    await t.pump(); // Start the ripple's animations.
    await t.pump(const Duration(milliseconds: 150));
    // The second press is held while the first ripple finishes fading out.
    final g = await t.startGesture(centre);
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    await g.up();
    await t.pumpAndSettle();

    final material = t.renderObject(
      find.descendant(
        of: find.byType(AppKeyButton),
        matching: find.byType(Material),
      ),
    );
    expect(material, paintsExactlyCountTimes(#drawCircle, 0));
  });
}
