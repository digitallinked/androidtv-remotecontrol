import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/features/remote/presentation/widgets/dpad.dart';
import 'package:tv_remote/features/remote/presentation/widgets/number_pad.dart';
import 'package:tv_remote/features/remote/presentation/widgets/pad_pager.dart';
import 'package:tv_remote/features/remote/presentation/widgets/touchpad.dart';

import '../../../helpers/key_input_recorder.dart';
import '../../../helpers/pump_app.dart';

void main() {
  late KeyInputRecorder rec;
  late List<PadPage> reported;

  setUp(() {
    rec = KeyInputRecorder();
    reported = [];
  });

  Future<void> pumpPager(
    WidgetTester t, {
    PadPage initial = PadPage.touchpad,
    bool disableAnimations = false,
    bool enabled = true,
    double textScale = 1,
  }) => pumpApp(
    t,
    SizedBox(
      width: 288,
      height: 400,
      child: PadPager(
        input: rec,
        initialPage: initial,
        onPageChanged: reported.add,
        enabled: enabled,
      ),
    ),
    disableAnimations: disableAnimations,
    textScale: textScale,
  );

  testWidgets('opens_on_the_initial_page', (t) async {
    await pumpPager(t, initial: PadPage.dpad);
    expect(find.byType(Dpad), findsOneWidget);
    expect(find.byType(Touchpad), findsNothing);
    expect(reported, isEmpty);
  });

  testWidgets('tab_tap_reports_the_page', (t) async {
    await pumpPager(t);
    await t.tap(find.text('D-pad'));
    await t.pumpAndSettle();
    expect(find.byType(Dpad), findsOneWidget);
    expect(reported, [PadPage.dpad]);
    await t.tap(find.text('Touchpad'));
    await t.pumpAndSettle();
    expect(find.byType(Touchpad), findsOneWidget);
    expect(reported, [PadPage.dpad, PadPage.touchpad]);
  });

  testWidgets('a_tab_across_a_page_reports_only_where_it_ends', (t) async {
    await pumpPager(t);
    await t.tap(find.text('Numbers'));
    await t.pumpAndSettle();
    expect(find.byType(NumberPad), findsOneWidget);
    // Touchpad to Numbers passes the D-pad: that must not be reported, or
    // the screen would save "D-pad" as the user's style.
    expect(reported, [PadPage.numbers]);
  });

  testWidgets('a_tab_jumps_with_reduce_motion', (t) async {
    await pumpPager(t, disableAnimations: true);
    await t.tap(find.text('Numbers'));
    await t.pump();
    expect(find.byType(NumberPad), findsOneWidget);
    expect(reported, [PadPage.numbers]);
  });

  testWidgets('swiping_the_touchpad_does_not_change_the_page', (t) async {
    await pumpPager(t);
    await t.fling(find.byType(Touchpad), const Offset(-250, 0), 1500);
    await t.pumpAndSettle();
    expect(find.byType(Touchpad), findsOneWidget);
    expect(find.byType(Dpad), findsNothing);
    expect(reported, isEmpty);
    // It was a swipe on the pad: the pad sent its steps.
    expect(rec.calls, contains('tap:21'));
  });

  testWidgets('swiping_from_the_dpad_page_moves_to_the_neighbours', (t) async {
    await pumpPager(t, initial: PadPage.dpad);
    await t.fling(find.byType(Dpad), const Offset(-250, 0), 1500);
    await t.pumpAndSettle();
    expect(find.byType(NumberPad), findsOneWidget);
    expect(reported, [PadPage.numbers]);
    await t.fling(find.byType(NumberPad), const Offset(250, 0), 1500);
    await t.pumpAndSettle();
    expect(find.byType(Dpad), findsOneWidget);
    expect(reported, [PadPage.numbers, PadPage.dpad]);
    await t.fling(find.byType(Dpad), const Offset(250, 0), 1500);
    await t.pumpAndSettle();
    expect(find.byType(Touchpad), findsOneWidget);
    expect(reported.last, PadPage.touchpad);
    // No key was sent by the swipes themselves.
    expect(rec.calls, isEmpty);
  });

  testWidgets('the_tabs_are_not_faded_when_the_pages_are', (t) async {
    await pumpPager(t, enabled: false);
    final opacities = t
        .widgetList<Opacity>(find.byType(Opacity))
        .where((o) => o.opacity == 0.4);
    expect(opacities, hasLength(1));
    expect(
      find.descendant(
        of: find.byWidget(opacities.single),
        matching: find.byType(SegmentedButton<PadPage>),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byWidget(opacities.single),
        matching: find.byType(Touchpad),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tabs_are_labelled_and_48dp_high', (t) async {
    final handle = t.ensureSemantics();
    await pumpPager(t);
    expect(find.bySemanticsLabel('Control style'), findsOneWidget);
    for (final label in ['Touchpad', 'D-pad', 'Numbers']) {
      final size = t.getSize(
        find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
      );
      expect(size.height, greaterThanOrEqualTo(48), reason: label);
    }
    handle.dispose();
  });

  testWidgets('tabs_fit_288dp_at_200_percent_text', (t) async {
    await pumpPager(t, textScale: 2);
    expect(t.takeException(), isNull);
    final strip = t.getRect(find.byType(SegmentedButton<PadPage>));
    expect(strip.width, lessThanOrEqualTo(288));
  });

  PageView pageView(WidgetTester t) =>
      t.widget<PageView>(find.byType(PageView));

  testWidgets('a_drag_past_halfway_changes_nothing_until_it_settles', (
    t,
  ) async {
    await pumpPager(t, initial: PadPage.dpad);
    expect(pageView(t).physics, isA<PageScrollPhysics>());
    final g = await t.startGesture(t.getCenter(find.byType(Dpad)));
    // The drag starts at the first move: 200 of 288 dp is past halfway.
    for (var i = 0; i < 3; i++) {
      await g.moveBy(const Offset(-100, 0));
    }
    await t.pump();
    for (var i = 0; i < 3; i++) {
      await g.moveBy(const Offset(100, 0)); // And back.
    }
    await t.pump(const Duration(milliseconds: 300));
    await g.up();
    await t.pumpAndSettle();
    expect(find.byType(Dpad), findsOneWidget);
    expect(reported, isEmpty);

    // Dragging to the touchpad past halfway keeps the drag alive.
    final h = await t.startGesture(t.getCenter(find.byType(Dpad)));
    for (var i = 0; i < 3; i++) {
      await h.moveBy(const Offset(100, 0));
    }
    await t.pump(const Duration(milliseconds: 300));
    expect(pageView(t).physics, isA<PageScrollPhysics>());
    await h.up();
    await t.pumpAndSettle();
    expect(find.byType(Touchpad), findsOneWidget);
    expect(reported, [PadPage.touchpad]);
    expect(pageView(t).physics, isA<NeverScrollableScrollPhysics>());
  });

  testWidgets('overlapping_tab_taps_report_only_the_last_page', (t) async {
    await pumpPager(t);
    await t.tap(find.text('D-pad'));
    await t.pump(const Duration(milliseconds: 60));
    await t.tap(find.text('Numbers'));
    await t.pumpAndSettle();
    expect(find.byType(NumberPad), findsOneWidget);
    expect(reported, [PadPage.numbers]);
  });
}
