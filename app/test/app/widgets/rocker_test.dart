import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/app/widgets/app_key_button.dart';
import 'package:tv_remote/app/widgets/rocker.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('rocker_up_and_down_call_callbacks', (t) async {
    var up = 0;
    var down = 0;
    await pumpApp(
      t,
      Rocker(
        label: 'VOL',
        upSemanticLabel: 'Volume up',
        downSemanticLabel: 'Volume down',
        onUp: () => up++,
        onDown: () => down++,
      ),
    );
    await t.tap(find.bySemanticsLabel('Volume up'));
    await t.pumpAndSettle();
    expect([up, down], [1, 0]);
    await t.tap(find.bySemanticsLabel('Volume down'));
    await t.pumpAndSettle();
    expect([up, down], [1, 1]);
  });

  testWidgets('rocker_hold_routes_to_matching_long_press_callbacks', (t) async {
    final log = <String>[];
    await pumpApp(
      t,
      Rocker(
        label: 'VOL',
        upSemanticLabel: 'Volume up',
        downSemanticLabel: 'Volume down',
        onUp: () => log.add('up'),
        onDown: () => log.add('down'),
        onUpLongPressStart: () => log.add('upStart'),
        onUpLongPressEnd: () => log.add('upEnd'),
        onDownLongPressStart: () => log.add('downStart'),
        onDownLongPressEnd: () => log.add('downEnd'),
      ),
    );
    await t.longPress(find.bySemanticsLabel('Volume down'));
    await t.pumpAndSettle();
    expect(log, ['downStart', 'downEnd']);
  });

  testWidgets('rocker_shows_label_and_value', (t) async {
    await pumpApp(
      t,
      Rocker(
        label: 'VOL',
        value: '12',
        upSemanticLabel: 'Volume up',
        downSemanticLabel: 'Volume down',
        onUp: () {},
        onDown: () {},
      ),
    );
    expect(find.text('VOL'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('rocker_reflows_at_200_percent_text', (t) async {
    await pumpApp(
      t,
      Rocker(
        label: 'VOL',
        value: '100',
        upSemanticLabel: 'Volume up',
        downSemanticLabel: 'Volume down',
        onUp: () {},
        onDown: () {},
      ),
      textScale: 2,
    );
    expect(t.takeException(), isNull);
    expect(
      t.getSize(find.bySemanticsLabel('Volume up')).height,
      greaterThanOrEqualTo(56),
    );
  });

  testWidgets('rocker_shrink_wraps_in_a_loose_parent', (t) async {
    await pumpApp(
      t,
      Rocker(
        label: 'VOL',
        upSemanticLabel: 'Volume up',
        downSemanticLabel: 'Volume down',
        onUp: () {},
        onDown: () {},
      ),
    );
    final s = t.getSize(find.byType(Rocker));
    expect(s.width, 64);
    // Two 56 dp keys, a 40 dp centre and 4 dp padding on each side.
    expect(s.height, 56 + 40 + 56 + 8);
  });

  testWidgets('rocker_passes_the_hold_duration_to_its_keys', (t) async {
    var starts = 0;
    await pumpApp(
      t,
      Rocker(
        label: 'VOL',
        upSemanticLabel: 'Volume up',
        downSemanticLabel: 'Volume down',
        onUp: () {},
        onDown: () {},
        longPressDuration: const Duration(milliseconds: 300),
        onUpLongPressStart: () => starts++,
        onUpLongPressEnd: () {},
      ),
    );
    final g = await t.startGesture(
      t.getCenter(find.bySemanticsLabel('Volume up')),
    );
    await t.pump(const Duration(milliseconds: 310));
    expect(starts, 1);
    await g.up();
    await t.pumpAndSettle();
  });

  testWidgets('rocker_value_semantics_is_one_node', (t) async {
    final h = t.ensureSemantics();
    await pumpApp(
      t,
      Rocker(
        label: 'VOL',
        value: '8',
        valueSemantics: 'Volume 8 of 20',
        upSemanticLabel: 'Volume up',
        downSemanticLabel: 'Volume down',
        onUp: () {},
        onDown: () {},
      ),
    );
    expect(find.bySemanticsLabel('Volume 8 of 20'), findsOneWidget);
    expect(find.bySemanticsLabel('VOL'), findsNothing);
    expect(find.bySemanticsLabel('8'), findsNothing);
    h.dispose();
  });

  testWidgets('rocker_without_value_semantics_reads_label_and_value', (
    t,
  ) async {
    final h = t.ensureSemantics();
    await pumpApp(
      t,
      Rocker(
        label: 'VOL',
        value: '8',
        upSemanticLabel: 'Volume up',
        downSemanticLabel: 'Volume down',
        onUp: () {},
        onDown: () {},
      ),
    );
    expect(find.bySemanticsLabel('VOL'), findsOneWidget);
    expect(find.bySemanticsLabel('8'), findsOneWidget);
    h.dispose();
  });

  testWidgets('rocker_keys_are_transparent_on_the_pill', (t) async {
    await pumpApp(
      t,
      Rocker(
        label: 'VOL',
        upSemanticLabel: 'Volume up',
        downSemanticLabel: 'Volume down',
        onUp: () {},
        onDown: () {},
      ),
    );
    final keys = t.widgetList<AppKeyButton>(find.byType(AppKeyButton));
    expect(keys, hasLength(2));
    expect(keys.map((k) => k.color), everyElement(Colors.transparent));
  });

  /// The scale [icon] is drawn at: the product of every [AnimatedScale] target
  /// above it, so a scale applied twice would show.
  double iconScale(WidgetTester t, IconData icon) {
    var scale = 1.0;
    t.element(find.byIcon(icon)).visitAncestorElements((e) {
      final w = e.widget;
      if (w is AnimatedScale) scale *= w.scale;
      return true;
    });
    return scale;
  }

  testWidgets('pressed_half_scales_its_icon', (t) async {
    final log = <String>[];
    await pumpApp(
      t,
      Rocker(
        label: 'VOL',
        upSemanticLabel: 'Volume up',
        downSemanticLabel: 'Volume down',
        onUp: () => log.add('up'),
        onDown: () => log.add('down'),
        onUpLongPressStart: () => log.add('upStart'),
        onUpLongPressEnd: () => log.add('upEnd'),
      ),
    );
    expect(iconScale(t, Icons.add), 1);
    expect(iconScale(t, Icons.remove), 1);

    final press = await t.startGesture(t.getCenter(find.byIcon(Icons.add)));
    await t.pump();
    expect(iconScale(t, Icons.add), AppMotion.pressScale);
    expect(iconScale(t, Icons.remove), 1);
    await t.pump(AppMotion.fast);
    expect(
      t
          .widget<ScaleTransition>(
            find.ancestor(
              of: find.byIcon(Icons.add),
              matching: find.byType(ScaleTransition),
            ),
          )
          .scale
          .value,
      AppMotion.pressScale,
    );

    // A hold is untouched by the press scale.
    await t.pump(kLongPressTimeout);
    expect(log, ['upStart']);
    await press.up();
    await t.pump();
    expect(log, ['upStart', 'upEnd']);
    expect(iconScale(t, Icons.add), 1);
    await t.pumpAndSettle();

    // A cancelled touch lets go of the scale too.
    final cancelled = await t.startGesture(
      t.getCenter(find.byIcon(Icons.remove)),
    );
    await t.pump();
    expect(iconScale(t, Icons.remove), AppMotion.pressScale);
    expect(iconScale(t, Icons.add), 1);
    await cancelled.cancel();
    await t.pump();
    expect(iconScale(t, Icons.remove), 1);
  });
}
