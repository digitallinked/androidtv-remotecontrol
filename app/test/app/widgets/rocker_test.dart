import 'package:flutter_test/flutter_test.dart';
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
}
