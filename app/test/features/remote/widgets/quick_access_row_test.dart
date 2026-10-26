import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/features/apps/data/starter_apps.dart';
import 'package:tv_remote/features/remote/presentation/widgets/quick_access_row.dart';
import 'package:tv_remote/features/remote/presentation/widgets/quick_app_tile.dart';

import '../../../helpers/key_input_recorder.dart';
import '../../../helpers/pump_app.dart';

void main() {
  late KeyInputRecorder rec;

  setUp(() => rec = KeyInputRecorder());

  Future<void> pumpBar(
    WidgetTester t,
    QuickAccessRow variant, {
    double width = 360,
    double textScale = 1,
    String? currentApp,
    Brightness brightness = Brightness.light,
  }) => pumpApp(
    t,
    SizedBox(
      width: width,
      child: QuickAccessBar(
        variant: variant,
        input: rec,
        apps: kStarterApps,
        currentApp: currentApp,
      ),
    ),
    textScale: textScale,
    brightness: brightness,
  );

  testWidgets('colour_keys_send_183_to_186', (t) async {
    await pumpBar(t, QuickAccessRow.colourKeys);
    for (final name in ['Red', 'Green', 'Yellow', 'Blue']) {
      await t.tap(find.bySemanticsLabel(name));
    }
    expect(rec.calls, ['tap:183', 'tap:184', 'tap:185', 'tap:186']);
  });

  testWidgets('media_row_sends_media_codes', (t) async {
    await pumpBar(t, QuickAccessRow.mediaKeys);
    for (final name in [
      'Previous',
      'Rewind',
      'Play or pause',
      'Fast forward',
      'Next',
    ]) {
      await t.tap(find.bySemanticsLabel(name));
    }
    expect(rec.calls, ['tap:88', 'tap:89', 'tap:85', 'tap:90', 'tap:87']);
  });

  testWidgets('none_renders_nothing', (t) async {
    await pumpBar(t, QuickAccessRow.none);
    expect(t.getSize(find.byType(QuickAccessBar)).height, 0);
    expect(find.byType(QuickAppTile), findsNothing);
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('app_tile_launches_the_app', (t) async {
    await pumpBar(t, QuickAccessRow.apps);
    await t.tap(find.bySemanticsLabel('Open Netflix'));
    expect(rec.calls, ['launch:com.netflix.ninja']);
  });

  testWidgets('current_app_is_marked_and_announced', (t) async {
    await pumpBar(
      t,
      QuickAccessRow.apps,
      currentApp: 'com.google.android.youtube.tv',
    );
    expect(find.bySemanticsLabel('YouTube, now on TV'), findsOneWidget);
    expect(find.bySemanticsLabel('Open YouTube'), findsNothing);
    expect(find.bySemanticsLabel('Open Netflix'), findsOneWidget);
    final dot = find.byKey(const ValueKey('quick_app_current_dot'));
    expect(dot, findsOneWidget);
    expect(t.getSize(dot), const Size(8, 8));
    // Tapping the current app still launches it.
    await t.tap(find.bySemanticsLabel('YouTube, now on TV'));
    expect(rec.calls, ['launch:com.google.android.youtube.tv']);
  });

  testWidgets('no_dot_when_no_app_is_current', (t) async {
    await pumpBar(t, QuickAccessRow.apps);
    expect(find.byKey(const ValueKey('quick_app_current_dot')), findsNothing);
  });

  testWidgets('app_tile_shows_letter_name_and_is_72_wide', (t) async {
    await pumpBar(t, QuickAccessRow.apps);
    final tile = find.byType(QuickAppTile).first;
    expect(t.getSize(tile).width, 72);
    expect(find.descendant(of: tile, matching: find.text('N')), findsOneWidget);
    expect(
      find.descendant(of: tile, matching: find.text('Netflix')),
      findsOneWidget,
    );
    final square = find.descendant(
      of: tile,
      matching: find.byKey(const ValueKey('quick_app_square')),
    );
    expect(t.getSize(square), const Size(56, 56));
  });

  testWidgets('containers_are_labelled_for_screen_readers', (t) async {
    for (final (variant, label) in [
      (QuickAccessRow.apps, 'Apps on your TV'),
      (QuickAccessRow.colourKeys, 'Colour keys'),
      (QuickAccessRow.mediaKeys, 'Media keys'),
    ]) {
      await pumpBar(t, variant);
      expect(find.bySemanticsLabel(label), findsOneWidget, reason: '$variant');
    }
  });

  test('colour_key_labels_meet_4_5_contrast', () {
    for (final c in [AppColors.dark, AppColors.light]) {
      for (final fill in [c.tvRed, c.tvGreen, c.tvYellow, c.tvBlue]) {
        expect(
          contrastRatio(colourKeyLabelColor(fill), fill),
          greaterThanOrEqualTo(4.5),
        );
      }
    }
    expect(
      colourKeyLabelColor(AppColors.dark.tvYellow),
      const Color(0xFF0F1115),
    );
    expect(colourKeyLabelColor(AppColors.dark.tvBlue), Colors.white);
  });

  testWidgets(
    'rows_scroll_instead_of_overflowing_at_320dp_and_200_percent_text',
    (t) async {
      for (final variant in [
        QuickAccessRow.apps,
        QuickAccessRow.colourKeys,
        QuickAccessRow.mediaKeys,
      ]) {
        for (final b in Brightness.values) {
          await pumpBar(
            t,
            variant,
            width: 288,
            textScale: 2,
            currentApp: 'com.netflix.ninja',
            brightness: b,
          );
          expect(t.takeException(), isNull, reason: '$variant ${b.name}');
        }
      }
    },
  );

  testWidgets('colour_keys_become_a_scrolling_list_when_narrow', (t) async {
    await pumpBar(t, QuickAccessRow.colourKeys, width: 288);
    // 288 - 2 * 16 = 256 < 4 * 64 + 3 * 8.
    expect(find.byType(ListView), findsOneWidget);
    await pumpBar(t, QuickAccessRow.colourKeys);
    expect(find.byType(ListView), findsNothing);
    final red = t.getSize(find.bySemanticsLabel('Red'));
    final blue = t.getSize(find.bySemanticsLabel('Blue'));
    expect(red.width, blue.width);
    expect(red.width, greaterThanOrEqualTo(64));
  });

  testWidgets('media_keys_are_centred_when_they_fit_else_scroll', (t) async {
    await pumpBar(t, QuickAccessRow.mediaKeys);
    expect(find.byType(ListView), findsNothing);
    final left = t.getTopLeft(find.bySemanticsLabel('Previous')).dx;
    final right = t.getTopRight(find.bySemanticsLabel('Next')).dx;
    final origin = t.getTopLeft(find.byType(QuickAccessBar)).dx;
    expect(left - origin, closeTo(origin + 360 - right, 0.5));
    await pumpBar(t, QuickAccessRow.mediaKeys, width: 288);
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('quick_keys_are_at_least_56dp', (t) async {
    await pumpBar(t, QuickAccessRow.colourKeys);
    for (final name in ['Red', 'Green', 'Yellow', 'Blue']) {
      final size = t.getSize(find.bySemanticsLabel(name));
      expect(size.height, 56, reason: name);
      expect(size.width, greaterThanOrEqualTo(56), reason: name);
    }
    await pumpBar(t, QuickAccessRow.mediaKeys);
    for (final name in ['Previous', 'Rewind', 'Play or pause', 'Next']) {
      final size = t.getSize(find.bySemanticsLabel(name));
      expect(size.width, greaterThanOrEqualTo(56), reason: name);
      expect(size.height, greaterThanOrEqualTo(56), reason: name);
    }
    final gap =
        t.getTopLeft(find.bySemanticsLabel('Rewind')).dx -
        t.getTopRight(find.bySemanticsLabel('Previous')).dx;
    expect(gap, greaterThanOrEqualTo(8));
  });

  testWidgets('refused_launch_records_nothing', (t) async {
    rec.connected = false;
    await pumpBar(t, QuickAccessRow.apps);
    await t.tap(find.bySemanticsLabel('Open Netflix'));
    expect(rec.calls, isEmpty);
    expect(rec.refused, 1);
  });
}
