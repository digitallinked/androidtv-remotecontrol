import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/app_theme.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';
import 'package:tv_remote/features/remote/presentation/widgets/quick_access_row.dart';
import 'package:tv_remote/features/remote/presentation/widgets/quick_app_tile.dart';

import '../../../helpers/key_input_recorder.dart';
import '../../../helpers/pump_app.dart';

/// The five apps the quick row tests show.
const List<AppEntry> _apps = [
  AppEntry(package: 'com.netflix.ninja', name: 'Netflix'),
  AppEntry(package: 'com.google.android.youtube.tv', name: 'YouTube'),
  AppEntry(package: 'com.amazon.amazonvideo.livingroom', name: 'Prime Video'),
  AppEntry(package: 'com.disney.disneyplus', name: 'Disney+'),
  AppEntry(package: 'com.spotify.tv.android', name: 'Spotify'),
];

/// Android 14's non-linear 200% font curve (its font scale converter): small
/// sizes double, large ones grow less, so a line is not `size * 2`.
class _NonlinearTwoX extends TextScaler {
  const _NonlinearTwoX();

  static const List<double> _from = [8, 10, 12, 14, 18, 20, 24, 30, 100];
  static const List<double> _to = [16, 20, 24, 26, 30, 34, 36, 38, 100];

  @override
  double scale(double fontSize) {
    if (fontSize <= _from.first) return fontSize * 2;
    for (var i = 1; i < _from.length; i++) {
      if (fontSize <= _from[i]) {
        final f = (fontSize - _from[i - 1]) / (_from[i] - _from[i - 1]);
        return _to[i - 1] + f * (_to[i] - _to[i - 1]);
      }
    }
    return fontSize;
  }

  @override
  double get textScaleFactor => 2;

  @override
  bool operator ==(Object other) => other is _NonlinearTwoX;

  @override
  int get hashCode => 2;
}

void main() {
  late KeyInputRecorder rec;

  setUp(() => rec = KeyInputRecorder());

  Future<void> pumpBar(
    WidgetTester t,
    QuickAccessRow variant, {
    double width = 360,
    double textScale = 1,
    String? currentApp,
    VoidCallback? onAllApps,
    Brightness brightness = Brightness.light,
  }) => pumpApp(
    t,
    SizedBox(
      width: width,
      child: QuickAccessBar(
        variant: variant,
        input: rec,
        apps: _apps,
        currentApp: currentApp,
        onAllApps: onAllApps,
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
    for (final name in [
      'Previous',
      'Rewind',
      'Play or pause',
      'Fast forward',
      'Next',
    ]) {
      final size = t.getSize(find.bySemanticsLabel(name));
      expect(size.width, greaterThanOrEqualTo(56), reason: name);
      expect(size.height, greaterThanOrEqualTo(56), reason: name);
    }
    final gap =
        t.getTopLeft(find.bySemanticsLabel('Rewind')).dx -
        t.getTopRight(find.bySemanticsLabel('Previous')).dx;
    expect(gap, greaterThanOrEqualTo(8));
  });

  testWidgets('app_tiles_fit_under_a_non_linear_200_percent_font_curve', (
    t,
  ) async {
    t.view
      ..physicalSize = const Size(320, 700)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildAppTheme(brightness: Brightness.light),
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const _NonlinearTwoX()),
          child: app!,
        ),
        home: Scaffold(
          body: QuickAccessBar(
            variant: QuickAccessRow.apps,
            input: rec,
            apps: _apps,
          ),
        ),
      ),
    );
    expect(t.takeException(), isNull);
    final bar = t.getRect(find.byType(ListView));
    final tile = find.byType(QuickAppTile).first;
    final name = t.getRect(
      find.descendant(of: tile, matching: find.text('Netflix')),
    );
    expect(name.bottom, lessThanOrEqualTo(bar.bottom));
    // The bar is the tile's height: a square, a gap and the name's line.
    expect(
      bar.height,
      moreOrLessEquals(
        QuickAppTile.squareSize + AppSpacing.xs + name.height,
        epsilon: 1,
      ),
    );
  });

  testWidgets('scrolling_rows_keep_their_gutter_inside_the_list', (t) async {
    for (final variant in [
      QuickAccessRow.colourKeys,
      QuickAccessRow.mediaKeys,
    ]) {
      await pumpBar(t, variant, width: 288);
      final bar = t.getRect(find.byType(QuickAccessBar));
      final list = find.byType(ListView);
      // The list spans the whole row, so the keys scroll under its edges and
      // are clipped there instead of painting outside the row.
      expect(t.getRect(list), bar, reason: '$variant');
      expect(
        t.widget<ListView>(list).clipBehavior,
        isNot(Clip.none),
        reason: '$variant',
      );
      final first = variant == QuickAccessRow.mediaKeys ? 'Previous' : 'Red';
      final last = variant == QuickAccessRow.mediaKeys ? 'Next' : 'Blue';
      expect(
        t.getTopLeft(find.bySemanticsLabel(first)).dx,
        bar.left + AppSpacing.l,
        reason: '$variant starts after the gutter',
      );

      // The last key can be scrolled into view, with the gutter after it.
      await t.drag(list, const Offset(-600, 0));
      await t.pumpAndSettle();
      final key = t.getRect(find.bySemanticsLabel(last));
      expect(key.right, bar.right - AppSpacing.l, reason: '$variant ends');
      expect(key.left, greaterThanOrEqualTo(bar.left), reason: '$variant');
    }
  });

  testWidgets('refused_launch_records_nothing', (t) async {
    rec.connected = false;
    await pumpBar(t, QuickAccessRow.apps);
    await t.tap(find.bySemanticsLabel('Open Netflix'));
    expect(rec.calls, isEmpty);
    expect(rec.refused, 1);
  });

  testWidgets('all_apps_tile_calls_back_and_sends_nothing', (t) async {
    final handle = t.ensureSemantics();
    var opened = 0;
    await pumpBar(t, QuickAccessRow.apps, onAllApps: () => opened++);
    // The last tile: the row is a lazy list, so bring it into view.
    await t.drag(find.byType(ListView), const Offset(-1000, 0));
    await t.pumpAndSettle();
    final all = find.bySemanticsLabel('All apps');
    expect(all, findsOneWidget);
    expect(
      t.getSemantics(all),
      isSemantics(isButton: true, hasTapAction: true),
    );
    await t.tap(all);
    expect(opened, 1);
    // Its caption is tappable too.
    await t.tap(find.text('All apps'));
    expect(opened, 2);
    // It is not a TV command.
    expect(rec.calls, isEmpty);
    expect(rec.refused, 0);
    handle.dispose();
  });

  testWidgets('all_apps_tile_is_the_last_tile_and_looks_like_a_tile', (
    t,
  ) async {
    await pumpBar(t, QuickAccessRow.apps, onAllApps: () {});
    // Scroll to the end of the row so the tile is built.
    await t.drag(find.byType(ListView), const Offset(-1000, 0));
    await t.pumpAndSettle();
    final square = find.byKey(const ValueKey('quick_all_apps_square'));
    expect(t.getSize(square), const Size(56, 56));
    expect(
      find.descendant(of: square, matching: find.byIcon(Icons.apps)),
      findsOneWidget,
    );
    final material = t.widget<Material>(
      find.descendant(of: square, matching: find.byType(Material)).first,
    );
    expect(material.color, AppColors.light.surface);
    expect(
      (material.shape! as RoundedRectangleBorder).side.color,
      AppColors.light.outline,
    );
    // Right of the last app tile.
    final spotify = t.getRect(find.byType(QuickAppTile).last);
    expect(t.getRect(square).left, greaterThan(spotify.right));
    expect(t.getSize(find.text('All apps')).height, greaterThan(0));
  });

  testWidgets('no_all_apps_tile_without_a_callback', (t) async {
    await pumpBar(t, QuickAccessRow.apps);
    await t.drag(find.byType(ListView), const Offset(-1000, 0));
    await t.pumpAndSettle();
    expect(find.bySemanticsLabel('All apps'), findsNothing);
    expect(find.byKey(const ValueKey('quick_all_apps_square')), findsNothing);
  });

  testWidgets('the_all_apps_tile_is_only_in_the_apps_variant', (t) async {
    for (final variant in [
      QuickAccessRow.colourKeys,
      QuickAccessRow.mediaKeys,
      QuickAccessRow.none,
    ]) {
      await pumpBar(t, variant, onAllApps: () {});
      expect(find.text('All apps'), findsNothing, reason: '$variant');
    }
  });

  testWidgets('all_apps_tile_fits_320dp_at_200_percent_text', (t) async {
    for (final b in Brightness.values) {
      await pumpBar(
        t,
        QuickAccessRow.apps,
        width: 288,
        textScale: 2,
        onAllApps: () {},
        brightness: b,
      );
      await t.drag(find.byType(ListView), const Offset(-1500, 0));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: b.name);
      expect(
        find.byKey(const ValueKey('quick_all_apps_square')),
        findsOneWidget,
      );
    }
  });
}
