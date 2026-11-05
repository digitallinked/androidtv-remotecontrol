import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/app_theme.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';
import 'package:tv_remote/features/apps/domain/app_logos.dart';
import 'package:tv_remote/features/apps/domain/shortcut_style.dart';
import 'package:tv_remote/features/apps/presentation/widgets/app_tile.dart';
import 'package:tv_remote/features/remote/presentation/widgets/quick_app_tile.dart';

import '../../helpers/pump_app.dart';

/// The fill of the square, read from the widget tree.
Color _fillOf(WidgetTester t) {
  final box = t.widget<DecoratedBox>(
    find.descendant(
      of: find.byType(AppIconSquare),
      matching: find.byType(DecoratedBox),
    ),
  );
  return (box.decoration as ShapeDecoration).color!;
}

/// Android 14's non-linear 200% font curve (see the quick row tests).
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

/// A bundle whose assets are all missing, or all hold [corrupt] when it is
/// set.
class _BrokenBundle extends CachingAssetBundle {
  _BrokenBundle({this.corrupt});

  final String? corrupt;

  @override
  Future<ByteData> load(String key) async {
    final text = corrupt;
    if (text == null) throw FlutterError('No asset $key');
    return ByteData.sublistView(Uint8List.fromList(text.codeUnits));
  }
}

/// Runs real time until [finder] shows: a corrupt file fails on an isolate.
Future<void> _waitFor(WidgetTester t, Finder finder) async {
  for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump();
  }
}

void main() {
  testWidgets('custom_entries_show_an_upper_case_monogram', (t) async {
    await pumpApp(
      t,
      const AppIconSquare(
        app: AppEntry(package: 'com.x.y', name: 'netflix', isCustom: true),
      ),
    );
    expect(find.text('N'), findsOneWidget);
    expect(find.text('n'), findsNothing);
  });

  testWidgets('the_monogram_is_the_first_grapheme_not_the_first_code_unit', (
    t,
  ) async {
    await pumpApp(
      t,
      const AppIconSquare(
        // "e" followed by a combining acute accent: one grapheme.
        app: AppEntry(package: 'com.x.y', name: 'éclair'),
      ),
    );
    expect(find.text('É'), findsOneWidget);
  });

  testWidgets('the_monogram_never_shrinks_at_100_or_200_percent_text', (
    t,
  ) async {
    for (final scale in const [1.0, 2.0]) {
      await pumpApp(
        t,
        const AppIconSquare(
          app: AppEntry(package: 'a.b', name: 'Plex'),
        ),
        textScale: scale,
      );
      final letter = find.text('P');
      final drawn = t.getBottomRight(letter) - t.getTopLeft(letter);
      expect(drawn.dy, greaterThanOrEqualTo(26), reason: '$scale');
    }
  });

  testWidgets('an_empty_name_draws_an_empty_square', (t) async {
    await pumpApp(
      t,
      const AppIconSquare(
        app: AppEntry(package: 'com.x.y', name: ''),
      ),
    );
    expect(t.takeException(), isNull);
    expect(t.getSize(find.byType(AppIconSquare)), const Size(56, 56));
  });

  testWidgets('plain_entries_use_the_raised_surface_and_primary_ink', (
    t,
  ) async {
    await pumpApp(
      t,
      const AppIconSquare(
        app: AppEntry(package: 'a.b', name: 'Plex'),
      ),
    );
    expect(_fillOf(t), AppColors.light.surfaceRaised);
    expect(
      t.widget<Text>(find.text('P')).style?.color,
      AppColors.light.textPrimary,
    );
  });

  testWidgets('custom_colour_and_icon_are_drawn_with_readable_ink', (t) async {
    for (final colour in kShortcutColors) {
      await pumpApp(
        t,
        AppIconSquare(
          app: AppEntry(
            package: 'a.b',
            name: 'Plex',
            isCustom: true,
            customColor: colour,
            customIcon: 'movies',
          ),
        ),
      );
      expect(_fillOf(t), colour);
      final icon = t.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Icons.movie_outlined);
      expect(icon.color, colourKeyLabelColor(colour));
      // The icon replaces the letter.
      expect(find.text('P'), findsNothing);
    }
    // A colour with the letter keeps the readable ink on the letter.
    await pumpApp(
      t,
      const AppIconSquare(
        app: AppEntry(
          package: 'a.b',
          name: 'Plex',
          isCustom: true,
          customColor: Color(0xFFF59E0B),
        ),
      ),
    );
    expect(
      t.widget<Text>(find.text('P')).style?.color,
      colourKeyLabelColor(const Color(0xFFF59E0B)),
    );
  });

  testWidgets('every_icon_id_draws_its_own_icon', (t) async {
    for (final MapEntry(:key, :value) in kShortcutIcons.entries) {
      await pumpApp(
        t,
        AppIconSquare(
          app: AppEntry(package: 'a.b', name: 'Plex', customIcon: key),
        ),
      );
      expect(t.widget<Icon>(find.byType(Icon)).icon, value, reason: key);
    }
  });

  test('every_shortcut_colour_has_a_readable_label', () {
    for (final c in kShortcutColors) {
      expect(
        contrastRatio(colourKeyLabelColor(c), c),
        greaterThanOrEqualTo(4.5),
        reason: '$c',
      );
    }
  });

  test('the_palette_is_the_eight_specified_colours', () {
    expect(
      [for (final c in kShortcutColors) c.toARGB32()],
      [
        0xFF475569,
        0xFF2563EB,
        0xFF0F766E,
        0xFF15803D,
        0xFFF59E0B,
        0xFFEA580C,
        0xFFDC2626,
        0xFF7C3AED,
      ],
    );
  });

  testWidgets('unknown_icon_id_falls_back_to_the_generic_icon', (t) async {
    await pumpApp(
      t,
      const AppIconSquare(
        app: AppEntry(package: 'a.b', name: 'Plex', customIcon: 'nope'),
      ),
    );
    expect(t.widget<Icon>(find.byType(Icon)).icon, Icons.apps);
  });

  testWidgets('colour_and_icon_names_are_localised', (t) async {
    late AppLocalizations l10n;
    await pumpApp(
      t,
      Builder(
        builder: (context) {
          l10n = AppLocalizations.of(context);
          return const SizedBox();
        },
      ),
    );
    expect(
      [for (final c in kShortcutColors) shortcutColourName(l10n, c)],
      ['Slate', 'Blue', 'Teal', 'Green', 'Amber', 'Orange', 'Red', 'Purple'],
    );
    expect(
      [for (final id in kShortcutIcons.keys) shortcutIconName(l10n, id)],
      [
        'App',
        'Movies',
        'Live TV',
        'Sports',
        'Music',
        'Kids',
        'News',
        'Games',
        'Learning',
      ],
    );
  });

  testWidgets('the_square_is_left_out_of_semantics', (t) async {
    final handle = t.ensureSemantics();
    await pumpApp(
      t,
      const AppIconSquare(
        app: AppEntry(package: 'a.b', name: 'Plex'),
      ),
    );
    expect(find.bySemanticsLabel('P'), findsNothing);
    handle.dispose();
  });

  testWidgets('app_tile_is_one_labelled_button', (t) async {
    final handle = t.ensureSemantics();
    var taps = 0;
    Widget tile({required bool current}) => SizedBox(
      width: 96,
      height: 130,
      child: AppTile(
        app: const AppEntry(package: 'com.netflix.ninja', name: 'Netflix'),
        isCurrent: current,
        onTap: () => taps++,
      ),
    );

    await pumpApp(t, tile(current: false));
    expect(find.bySemanticsLabel('Open Netflix'), findsOneWidget);
    expect(
      t.getSemantics(find.bySemanticsLabel('Open Netflix')),
      isSemantics(isButton: true, hasTapAction: true),
    );
    // Nothing else is announced: the square and the name are inside it.
    expect(find.bySemanticsLabel('N'), findsNothing);
    expect(find.bySemanticsLabel('Netflix'), findsNothing);
    await t.tap(find.text('Netflix'));
    await t.tap(find.byType(AppIconSquare));
    expect(taps, 2);
    expect(find.byKey(const ValueKey('app_tile_current_dot')), findsNothing);

    await pumpApp(t, tile(current: true));
    expect(find.bySemanticsLabel('Netflix, now on TV'), findsOneWidget);
    expect(find.bySemanticsLabel('Open Netflix'), findsNothing);
    final dot = find.byKey(const ValueKey('app_tile_current_dot'));
    expect(t.getSize(dot), const Size(8, 8));
    handle.dispose();
  });

  testWidgets('app_tile_fills_its_cell', (t) async {
    await pumpApp(
      t,
      Align(
        child: SizedBox(
          width: 90,
          height: 130,
          child: AppTile(
            app: const AppEntry(package: 'a.b', name: 'Plex'),
            isCurrent: false,
            onTap: () {},
          ),
        ),
      ),
    );
    expect(t.getSize(find.byType(AppTile)), const Size(90, 130));
    expect(t.getSize(find.byType(InkWell)), const Size(90, 130));
    expect(t.getSize(find.byType(AppIconSquare)), const Size(56, 56));
  });

  testWidgets('app_tile_names_wrap_to_two_lines_then_ellipsise', (t) async {
    const name = 'A very long application name that cannot fit';
    await pumpApp(
      t,
      SizedBox(
        width: 80,
        height: 140,
        child: AppTile(
          app: const AppEntry(package: 'a.b', name: name),
          isCurrent: false,
          onTap: () {},
        ),
      ),
    );
    final text = t.widget<Text>(find.text(name));
    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.textAlign, TextAlign.center);
  });

  testWidgets('heightOf_holds_a_two_line_name_under_a_non_linear_200_percent', (
    t,
  ) async {
    t.view
      ..physicalSize = const Size(320, 700)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    const name = 'Amazon Prime Video Kids';
    late double height;
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
          body: Builder(
            builder: (context) {
              height = AppTile.heightOf(context);
              return Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 83,
                  height: height,
                  child: AppTile(
                    app: const AppEntry(package: 'a.b', name: name),
                    isCurrent: true,
                    onTap: () {},
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    // A text that did not fit would have been thrown as a layout error.
    expect(t.takeException(), isNull);
    final cell = t.getRect(find.byType(AppTile));
    final label = t.getRect(find.text(name));
    expect(label.bottom, lessThanOrEqualTo(cell.bottom));
    // The cell holds the square, the gap and exactly two scaled lines when
    // the name needs them.
    expect(label.height, greaterThan(40));
    expect(
      height,
      moreOrLessEquals(
        2 * AppSpacing.xs + 56 + AppSpacing.xs + label.height,
        epsilon: 2,
      ),
    );
  });

  testWidgets('now_on_tv_dot_has_a_contrasting_ring', (t) async {
    for (final b in Brightness.values) {
      final colors = b == Brightness.light ? AppColors.light : AppColors.dark;
      for (final custom in <Color?>[null, ...kShortcutColors]) {
        final reason = '${b.name} $custom';
        await pumpApp(
          t,
          SizedBox(
            width: 96,
            height: 130,
            child: AppTile(
              app: AppEntry(
                package: 'a.b',
                name: 'Plex',
                isCustom: custom != null,
                customColor: custom,
              ),
              isCurrent: true,
              onTap: () {},
            ),
          ),
          brightness: b,
        );
        // The theme animates from the previous brightness.
        await t.pumpAndSettle();
        final fill = _fillOf(t);
        expect(fill, custom ?? colors.surfaceRaised, reason: reason);
        final dot = find.byType(NowOnTvDot);
        expect(dot, findsOneWidget, reason: reason);
        expect(
          contrastRatio(t.widget<NowOnTvDot>(dot).ringColor, fill),
          greaterThanOrEqualTo(4.5),
          reason: reason,
        );
        expect(t.getSize(dot), const Size.square(NowOnTvDot.size));
        expect(NowOnTvDot.size, 12);
        final inner = find.byKey(const ValueKey('app_tile_current_dot'));
        expect(
          find.descendant(of: dot, matching: inner),
          findsOneWidget,
          reason: reason,
        );
        expect(t.getSize(inner), const Size(8, 8), reason: reason);
        final decoration =
            t.widget<Container>(inner).decoration! as BoxDecoration;
        expect(decoration.color, colors.accent, reason: reason);
        // The ring and the dot share a centre.
        expect(t.getCenter(inner), t.getCenter(dot), reason: reason);
      }
    }
  });

  testWidgets('pressing_a_tile_scales_its_square', (t) async {
    for (final reduceMotion in [false, true]) {
      var taps = 0;
      await pumpApp(
        t,
        SizedBox(
          width: 96,
          height: 120,
          child: AppTile(
            app: const AppEntry(package: 'a.b', name: 'Films'),
            isCurrent: false,
            onTap: () => taps++,
          ),
        ),
        disableAnimations: reduceMotion,
      );
      final square = find.ancestor(
        of: find.byType(AppIconSquare),
        matching: find.byType(AnimatedScale),
      );
      expect(square, findsOneWidget);
      expect(t.widget<AnimatedScale>(square).scale, 1);

      final press = await t.startGesture(t.getCenter(find.byType(AppTile)));
      await t.pump(kPressTimeout);
      expect(t.widget<AnimatedScale>(square).scale, AppMotion.pressScale);
      expect(
        t.widget<AnimatedScale>(square).duration,
        reduceMotion ? Duration.zero : AppMotion.fast,
      );
      // The name is not part of the square and keeps its size.
      expect(
        find.ancestor(of: find.text('Films'), matching: square),
        findsNothing,
      );
      await press.up();
      await t.pump();
      expect(t.widget<AnimatedScale>(square).scale, 1);
      expect(taps, 1);
      await t.pumpAndSettle();
    }
  });

  group('logos', () {
    const netflix = AppEntry(package: 'com.netflix.ninja', name: 'Netflix');
    final logo = kAppLogos[netflix.package]!;

    testWidgets('a_mapped_app_draws_its_logo_on_the_dark_tile', (t) async {
      for (final b in Brightness.values) {
        await pumpApp(t, const AppIconSquare(app: netflix), brightness: b);
        await t.pumpAndSettle();
        expect(_fillOf(t), const Color(0xFF141414), reason: b.name);
        expect(find.text('N'), findsNothing, reason: b.name);
        final picture = t.widget<SvgPicture>(find.byType(SvgPicture));
        expect(
          picture.colorFilter,
          ColorFilter.mode(logo.ink, BlendMode.srcIn),
          reason: b.name,
        );
      }
    });

    testWidgets('the_logo_is_six_tenths_of_the_square_and_centred', (t) async {
      for (final size in const [40.0, 56.0, 72.0]) {
        await pumpApp(t, AppIconSquare(app: netflix, size: size));
        await t.pumpAndSettle();
        final drawn = find.byType(SvgPicture);
        expect(t.getSize(drawn), Size.square(size * 0.6), reason: '$size');
        expect(
          t.getCenter(drawn),
          t.getCenter(find.byType(AppIconSquare)),
          reason: '$size',
        );
      }
    });

    testWidgets('a_custom_shortcut_of_a_mapped_package_gets_the_logo', (
      t,
    ) async {
      await pumpApp(
        t,
        const AppIconSquare(
          app: AppEntry(
            package: 'com.netflix.ninja',
            name: 'Films',
            isCustom: true,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.text('F'), findsNothing);
    });

    testWidgets('a_style_of_the_user_wins_over_the_logo', (t) async {
      const colour = Color(0xFF2563EB);
      await pumpApp(
        t,
        const AppIconSquare(
          app: AppEntry(
            package: 'com.netflix.ninja',
            name: 'Netflix',
            customColor: colour,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(SvgPicture), findsNothing);
      expect(find.text('N'), findsOneWidget);
      expect(_fillOf(t), colour);

      await pumpApp(
        t,
        const AppIconSquare(
          app: AppEntry(
            package: 'com.netflix.ninja',
            name: 'Netflix',
            customIcon: 'live',
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(SvgPicture), findsNothing);
      expect(t.widget<Icon>(find.byType(Icon)).icon, Icons.live_tv_outlined);
      expect(_fillOf(t), AppColors.light.surfaceRaised);
    });

    testWidgets('an_unmapped_app_keeps_the_letter', (t) async {
      await pumpApp(
        t,
        const AppIconSquare(
          app: AppEntry(package: 'a.b', name: 'Netflix'),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(SvgPicture), findsNothing);
      expect(find.text('N'), findsOneWidget);
    });

    testWidgets('the_dot_on_a_logo_tile_has_a_contrasting_ring', (t) async {
      await pumpApp(
        t,
        SizedBox(
          width: 96,
          height: 130,
          child: AppTile(app: netflix, isCurrent: true, onTap: () {}),
        ),
      );
      await t.pumpAndSettle();
      expect(
        contrastRatio(
          t.widget<NowOnTvDot>(find.byType(NowOnTvDot)).ringColor,
          kAppLogoTile,
        ),
        greaterThanOrEqualTo(4.5),
      );
    });

    for (final b in Brightness.values) {
      testWidgets('logo_tiles_keep_their_semantics_at_320_dp_200_${b.name}', (
        t,
      ) async {
        t.view
          ..physicalSize = const Size(320, 700)
          ..devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final handle = t.ensureSemantics();
        await pumpApp(
          t,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Builder(
                builder: (context) => SizedBox(
                  width: 83,
                  height: AppTile.heightOf(context),
                  child: AppTile(app: netflix, isCurrent: false, onTap: () {}),
                ),
              ),
              Builder(
                builder: (context) => SizedBox(
                  height: QuickAppTile.heightOf(context),
                  child: QuickAppTile(
                    app: const AppEntry(
                      package: 'com.google.android.youtube.tv',
                      name: 'YouTube',
                    ),
                    isCurrent: true,
                    onTap: () {},
                  ),
                ),
              ),
            ],
          ),
          brightness: b,
          textScaler: const _NonlinearTwoX(),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.byType(SvgPicture), findsNWidgets(2));
        expect(
          t.getSemantics(find.bySemanticsLabel('Open Netflix')),
          isSemantics(isButton: true, hasTapAction: true),
        );
        expect(find.bySemanticsLabel('YouTube, now on TV'), findsOneWidget);
        // The logo says nothing: only the tile does.
        expect(find.bySemanticsLabel('Netflix'), findsNothing);
        expect(find.bySemanticsLabel('N'), findsNothing);
        handle.dispose();
      });
    }
  });

  group('a_failed_logo', () {
    const netflix = AppEntry(package: 'com.netflix.ninja', name: 'Netflix');

    testWidgets('that_is_missing_shows_the_letter_and_throws_nothing', (
      t,
    ) async {
      final bundle = _BrokenBundle();
      await pumpApp(
        t,
        DefaultAssetBundle(
          bundle: bundle,
          child: const AppIconSquare(app: netflix),
        ),
      );
      await _waitFor(t, find.text('N'));
      expect(find.text('N'), findsOneWidget);
      expect(t.takeException(), isNull);
      expect(
        t.widget<Text>(find.text('N')).style?.color,
        colourKeyLabelColor(kAppLogoTile),
      );
      expect(_fillOf(t), kAppLogoTile);

      // A tile built again, as a list does on scrolling back, fails the same
      // way.
      await pumpApp(t, const SizedBox());
      await pumpApp(
        t,
        DefaultAssetBundle(
          bundle: bundle,
          child: const AppIconSquare(app: netflix),
        ),
      );
      await _waitFor(t, find.text('N'));
      expect(find.text('N'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('that_is_corrupt_shows_the_letter_and_throws_nothing', (
      t,
    ) async {
      await pumpApp(
        t,
        DefaultAssetBundle(
          bundle: _BrokenBundle(corrupt: '<svg not really'),
          child: const AppIconSquare(app: netflix),
        ),
      );
      await _waitFor(t, find.text('N'));
      expect(find.text('N'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });
}
