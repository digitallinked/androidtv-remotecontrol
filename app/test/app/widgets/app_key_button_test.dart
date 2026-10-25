import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/widgets/app_key_button.dart';

import '../../helpers/pump_app.dart';

Widget key({
  VoidCallback? onTap,
  VoidCallback? start,
  VoidCallback? end,
  Duration d = kLongPressTimeout,
}) => AppKeyButton(
  semanticLabel: 'Volume up',
  icon: const Icon(Icons.add),
  onTap: onTap ?? () {},
  onLongPressStart: start,
  onLongPressEnd: end,
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
    final log = <String>[];
    await pumpApp(
      t,
      key(
        onTap: () => log.add('tap'),
        start: () => log.add('start'),
        end: () => log.add('end'),
      ),
    );
    expect(find.bySemanticsLabel('Volume up'), findsOneWidget);
    t.semantics.longPress(find.semantics.byLabel('Volume up'));
    await t.pumpAndSettle();
    expect(log, ['start', 'end']);
    h.dispose();
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
