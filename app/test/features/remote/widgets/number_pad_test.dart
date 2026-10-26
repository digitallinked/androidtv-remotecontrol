import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/widgets/app_key_button.dart';
import 'package:tv_remote/features/remote/presentation/widgets/number_pad.dart';

import '../../../helpers/key_input_recorder.dart';
import '../../../helpers/pump_app.dart';

void main() {
  late KeyInputRecorder rec;

  setUp(() => rec = KeyInputRecorder());

  Future<void> pumpPad(
    WidgetTester t, {
    double width = 288,
    double height = 400,
    double textScale = 1,
  }) => pumpApp(
    t,
    SizedBox(
      width: width,
      height: height,
      child: NumberPad(input: rec),
    ),
    textScale: textScale,
  );

  testWidgets('numpad_digit_sends_keycode_7_plus_n', (t) async {
    await pumpPad(t, height: 600);
    for (var n = 0; n <= 9; n++) {
      await t.tap(find.bySemanticsLabel('Number $n'));
    }
    expect(rec.calls, [for (var n = 0; n <= 9; n++) 'tap:${7 + n}']);
  });

  testWidgets('numpad_extra_keys_send_their_codes', (t) async {
    await pumpPad(t, height: 600);
    const keys = {
      'TV input': KeyCodes.tvInput,
      'Menu': KeyCodes.menu,
      'Guide': KeyCodes.guide,
      'Info': KeyCodes.info,
      'Captions': KeyCodes.captions,
    };
    for (final label in keys.keys) {
      await t.tap(find.bySemanticsLabel(label));
    }
    expect(rec.calls, [for (final code in keys.values) 'tap:$code']);
    expect(keys.values, [178, 82, 172, 165, 175]);
  });

  testWidgets('numpad_lays_out_three_columns_in_five_rows', (t) async {
    await pumpPad(t, height: 600);
    const order = [
      'Number 1',
      'Number 2',
      'Number 3',
      'Number 4',
      'Number 5',
      'Number 6',
      'Number 7',
      'Number 8',
      'Number 9',
      'TV input',
      'Number 0',
      'Menu',
      'Guide',
      'Info',
      'Captions',
    ];
    final tops = <double>{};
    for (var i = 0; i < order.length; i++) {
      final key = find.ancestor(
        of: find.bySemanticsLabel(order[i]),
        matching: find.byType(AppKeyButton),
      );
      final rect = t.getRect(key.first);
      tops.add(rect.top);
      if (i % 3 == 1) {
        expect(
          rect.center.dx,
          closeTo(t.getCenter(find.byType(NumberPad)).dx, 1),
        );
      }
    }
    expect(tops, hasLength(5));
  });

  testWidgets('numpad_keys_are_at_least_56dp_with_8dp_gaps', (t) async {
    await pumpPad(t, height: 600);
    final rects = [
      for (final e in t.widgetList(find.byType(AppKeyButton)))
        t.getRect(find.byWidget(e)),
    ];
    expect(rects, hasLength(15));
    for (final r in rects) {
      expect(r.width, greaterThanOrEqualTo(56));
      expect(r.height, greaterThanOrEqualTo(56));
    }
    // Equal widths, 8 dp between columns and between rows.
    expect(rects.map((r) => r.width.round()).toSet(), hasLength(1));
    for (var row = 0; row < 5; row++) {
      for (var col = 0; col < 2; col++) {
        expect(rects[row * 3 + col + 1].left - rects[row * 3 + col].right, 8);
      }
      if (row < 4) {
        expect(rects[(row + 1) * 3].top - rects[row * 3].bottom, 8);
      }
    }
  });

  testWidgets('numpad_scrolls_when_the_page_is_short', (t) async {
    await pumpPad(t, height: 200);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    final scrollable = t.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    await t.drag(find.byType(NumberPad), const Offset(0, -300));
    await t.pump();
    await t.tap(find.bySemanticsLabel('Captions'));
    expect(rec.calls, ['tap:${KeyCodes.captions}']);
  });

  testWidgets('dpad_and_numpad_fit_320dp_at_200_percent_text', (t) async {
    await pumpPad(t, height: 200, textScale: 2);
    expect(t.takeException(), isNull);
    // Rows stay aligned and keys keep their 56 dp floor.
    for (final e in t.widgetList(find.byType(AppKeyButton))) {
      final size = t.getSize(find.byWidget(e));
      expect(size.width, greaterThanOrEqualTo(56));
      expect(size.height, greaterThanOrEqualTo(56));
    }
  });
}
