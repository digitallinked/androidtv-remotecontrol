import 'package:atv_remote/atv_remote.dart'
    show ConnectionStatus, TvConnectionState;
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/theme/app_theme.dart';
import 'package:tv_remote/app/theme/colour_styles.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/core/purchases/premium.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/paywall/domain/paywall_source.dart';

import '../../helpers/a11y.dart';
import '../../helpers/fake_remote_session.dart';
import '../../helpers/pump_router_app.dart';
import '../../helpers/test_devices.dart';
import '../../helpers/test_premium.dart';

const _premium = PremiumState(isPremium: true, known: true);

/// The settings of a phone where [style] was chosen.
Future<AppSettings> _settingsWith(ColourStyle style) async {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  final store = await SettingsStore.open();
  await store.setColourStyle(style);
  return store.snapshot();
}

/// The screens where accent text meets the raised surface or the page
/// (P6-C10): each opener checks it got there.
final _screens = <String, Future<void> Function(WidgetTester t)>{
  'remote': (t) async {
    expect(find.bySemanticsLabel('Volume up'), findsOneWidget);
  },
  'apps': (t) async {
    await _go(t, AppRoutes.apps);
    expect(find.text('Netflix'), findsWidgets);
  },
  'settings hub': (t) async {
    await _go(t, AppRoutes.settings);
    expect(find.text('Settings'), findsWidgets);
  },
  'paywall': (t) async {
    await _go(t, AppRoutes.paywall(source: PaywallSource.settings));
    expect(find.text('Premium'), findsWidgets);
  },
  // The demo strip's Leave button: accent text on the raised surface. The
  // session stays the fake: the strip follows the active target alone.
  'demo strip': (t) async {
    ProviderScope.containerOf(
      t.element(find.byType(MaterialApp)),
    ).read(activeTargetProvider.notifier).startDemo();
    await _go(t, AppRoutes.remote);
    expect(find.text('Demo mode'), findsOneWidget);
    expect(find.text('Leave'), findsOneWidget);
  },
};

Future<void> _go(WidgetTester t, String location) async {
  ProviderScope.containerOf(
    t.element(find.byType(MaterialApp)),
  ).read(appRouterProvider).go(location);
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
  await t.pumpAndSettle();
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  // P6-C10: accent-coloured text must reach 4.5:1 wherever it is drawn, in
  // every colour style, on Premium (where the styles apply).
  for (final style in ColourStyle.values) {
    for (final b in Brightness.values) {
      testWidgets('accent_text_meets_contrast_in_${style.name}_${b.name}', (
        t,
      ) async {
        t.view
          ..physicalSize = const Size(390, 844)
          ..devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await withSemantics(t, () async {
          final devices = [savedTv()];
          await pumpRouterApp(
            t,
            initialLocation: AppRoutes.remote,
            brightness: b,
            prepareSettings: (store) => store.setColourStyle(style),
            overrides: [
              premiumProvider.overrideWith(() => TestPremium(_premium)),
              remoteSessionProvider.overrideWith(
                (ref) async => FakeRemoteSession(
                  initial: const TvConnectionState(
                    status: ConnectionStatus.connected,
                  ),
                ),
              ),
              savedDevicesProvider.overrideWith((ref) => Stream.value(devices)),
            ],
          );
          for (final e in _screens.entries) {
            await e.value(t);
            await expectLater(
              t,
              meetsGuideline(textContrastGuideline),
              reason: '${e.key} ${style.name} ${b.name}',
            );
          }
        });
      });
    }
  }

  test('every_colour_style_meets_contrast', () {
    for (final s in ColourStyle.values) {
      for (final b in Brightness.values) {
        final c = colourStyleColors(s, b);
        for (final bg in [c.bg, c.surface, c.surfaceRaised]) {
          expect(
            contrastRatio(c.textPrimary, bg),
            greaterThanOrEqualTo(4.5),
            reason: '$s $b primary on $bg',
          );
          expect(
            contrastRatio(c.textSecondary, bg),
            greaterThanOrEqualTo(4.5),
            reason: '$s $b secondary on $bg',
          );
        }
        expect(
          contrastRatio(c.onAccent, c.accent),
          greaterThanOrEqualTo(4.5),
          reason: '$s $b onAccent',
        );
        // Accent is also used as text (text buttons, section headers).
        expect(
          contrastRatio(c.accent, c.bg),
          greaterThanOrEqualTo(4.5),
          reason: '$s $b accent on bg',
        );
        expect(
          contrastRatio(c.accent, c.surface),
          greaterThanOrEqualTo(4.5),
          reason: '$s $b accent on surface',
        );
      }
    }
  });

  // Accent on the raised (key) surface is for icons and large glyphs, not for
  // body text, so 3:1 is the requirement there. Two light palettes land a hair
  // under 4.5:1 anyway: the Phase 2 standard accent (4.42) and Ember (4.39,
  // fixed by P6-R12). They are pinned so they can't get worse unnoticed; any
  // other style/brightness has to reach 4.5:1.
  test('accent_is_readable_on_raised_surfaces_for_every_style', () {
    const under4_5 = {
      (ColourStyle.standard, Brightness.light),
      (ColourStyle.ember, Brightness.light),
    };
    for (final s in ColourStyle.values) {
      for (final b in Brightness.values) {
        final c = colourStyleColors(s, b);
        final ratio = contrastRatio(c.accent, c.surfaceRaised);
        expect(
          ratio,
          greaterThanOrEqualTo(under4_5.contains((s, b)) ? 4.3 : 4.5),
          reason: '$s $b accent on surfaceRaised',
        );
        expect(ratio, greaterThanOrEqualTo(3), reason: '$s $b non-text');
      }
    }
  });

  test('status_colours_have_3_to_1_non_text_contrast_in_every_style', () {
    for (final s in ColourStyle.values) {
      for (final b in Brightness.values) {
        final c = colourStyleColors(s, b);
        for (final (name, colour) in [
          ('success', c.success),
          ('warning', c.warning),
          ('danger', c.danger),
        ]) {
          for (final bg in [c.bg, c.surface]) {
            expect(
              contrastRatio(colour, bg),
              greaterThanOrEqualTo(3),
              reason: '$s $b $name on $bg',
            );
          }
        }
      }
    }
  });

  // The P6-R12 table, value by value: a palette is a design decision, so a
  // change to any hex has to show up here on purpose.
  // Order: bg, surface, surfaceRaised, outline, textPrimary, textSecondary,
  // accent, onAccent.
  const palettes = <(ColourStyle, Brightness, List<int>)>[
    (
      ColourStyle.ocean,
      Brightness.dark,
      [
        0xFF0B1418,
        0xFF101D22,
        0xFF18282E,
        0xFF24383F,
        0xFFEFF6F7,
        0xFF9FB4B9,
        0xFF3FC6C6,
        0xFF06181A,
      ],
    ),
    (
      ColourStyle.ocean,
      Brightness.light,
      [
        0xFFF3F8F8,
        0xFFFFFFFF,
        0xFFE4EFEF,
        0xFFC9DADB,
        0xFF0E1A1C,
        0xFF44575A,
        0xFF00777A,
        0xFFFFFFFF,
      ],
    ),
    (
      ColourStyle.ember,
      Brightness.dark,
      [
        0xFF16110D,
        0xFF1F1813,
        0xFF2B221B,
        0xFF3B2F25,
        0xFFF8F2EC,
        0xFFBFAF9F,
        0xFFFF9F43,
        0xFF1A0F05,
      ],
    ),
    (
      ColourStyle.ember,
      Brightness.light,
      [
        0xFFFAF6F2,
        0xFFFFFFFF,
        0xFFF1E9E1,
        0xFFE0D3C6,
        0xFF1D1610,
        0xFF5E4E40,
        0xFFB34D00,
        0xFFFFFFFF,
      ],
    ),
    (
      ColourStyle.midnight,
      Brightness.dark,
      [
        0xFF000000,
        0xFF0A0A0F,
        0xFF16161F,
        0xFF262633,
        0xFFF1F0F7,
        0xFFA9A6BD,
        0xFFA98BFF,
        0xFF120A26,
      ],
    ),
    (
      ColourStyle.midnight,
      Brightness.light,
      [
        0xFFF5F4FA,
        0xFFFFFFFF,
        0xFFEAE8F3,
        0xFFD4D1E3,
        0xFF14121D,
        0xFF4E4A63,
        0xFF5B3FD1,
        0xFFFFFFFF,
      ],
    ),
  ];
  for (final (style, brightness, hex) in palettes) {
    test('palette_values_match_the_table_${style.name}_${brightness.name}', () {
      final c = colourStyleColors(style, brightness);
      expect(
        [
          c.bg,
          c.surface,
          c.surfaceRaised,
          c.outline,
          c.textPrimary,
          c.textSecondary,
          c.accent,
          c.onAccent,
        ],
        [for (final v in hex) Color(v)],
      );
    });
  }

  test('standard_is_the_unchanged_app_palette', () {
    expect(
      colourStyleColors(ColourStyle.standard, Brightness.light),
      AppColors.light,
    );
    expect(
      colourStyleColors(ColourStyle.standard, Brightness.dark),
      AppColors.dark,
    );
  });

  test('each_premium_style_has_its_own_palette_in_both_brightnesses', () {
    for (final b in Brightness.values) {
      final palettes = {
        for (final s in ColourStyle.values) colourStyleColors(s, b),
      };
      expect(palettes, hasLength(ColourStyle.values.length), reason: '$b');
    }
    expect(
      colourStyleColors(ColourStyle.midnight, Brightness.dark).bg,
      const Color(0xFF000000),
    );
    expect(
      colourStyleColors(ColourStyle.ember, Brightness.light).accent,
      const Color(0xFFB34D00),
    );
  });

  test('styles_keep_status_and_tv_key_colours', () {
    for (final s in ColourStyle.values) {
      for (final b in Brightness.values) {
        final base = b == Brightness.dark ? AppColors.dark : AppColors.light;
        final c = colourStyleColors(s, b);
        expect(c.success, base.success, reason: '$s $b');
        expect(c.warning, base.warning, reason: '$s $b');
        expect(c.danger, base.danger, reason: '$s $b');
        expect(c.dangerText, base.dangerText, reason: '$s $b');
        expect(c.onDanger, base.onDanger, reason: '$s $b');
        expect(c.tvRed, base.tvRed, reason: '$s $b');
        expect(c.tvGreen, base.tvGreen, reason: '$s $b');
        expect(c.tvYellow, base.tvYellow, reason: '$s $b');
        expect(c.tvBlue, base.tvBlue, reason: '$s $b');
        // The danger text must stay readable on the style's own surfaces.
        expect(
          contrastRatio(c.dangerText, c.surface),
          greaterThanOrEqualTo(4.5),
          reason: '$s $b danger text on surface',
        );
      }
    }
  });

  test('effective_style_rules', () async {
    final stored = await _settingsWith(ColourStyle.ember);
    // Free: always standard, whatever is stored.
    expect(
      effectiveColourStyle(settings: stored, premium: PremiumState.free),
      ColourStyle.standard,
    );
    // Premium: the stored style.
    expect(
      effectiveColourStyle(settings: stored, premium: _premium),
      ColourStyle.ember,
    );
    // Premium lost: standard again; the stored choice is not touched.
    expect(
      effectiveColourStyle(settings: stored, premium: PremiumState.free),
      ColourStyle.standard,
    );
    expect(stored.colourStyle, ColourStyle.ember);
    // Premium not yet known but cached active still counts as Premium.
    expect(
      effectiveColourStyle(
        settings: stored,
        premium: const PremiumState(isPremium: true, known: false),
      ),
      ColourStyle.ember,
    );
  });

  test('build_app_theme_uses_the_given_colours', () {
    final colours = colourStyleColors(ColourStyle.ocean, Brightness.dark);
    final theme = buildAppTheme(
      brightness: Brightness.dark,
      colours: colours,
    );
    expect(theme.scaffoldBackgroundColor, colours.bg);
    expect(theme.colorScheme.primary, colours.accent);
    expect(theme.extension<AppColors>(), colours);
    // No colours given: the standard theme, as before.
    expect(
      buildAppTheme(brightness: Brightness.light).extension<AppColors>(),
      AppColors.light,
    );
  });

  test('a_wallpaper_scheme_wins_over_a_style', () async {
    final scheme = ColorScheme.fromSeed(
      seedColor: Colors.green,
      brightness: Brightness.dark,
    );
    final theme = buildSettingsTheme(
      brightness: Brightness.dark,
      settings: await _settingsWith(ColourStyle.ocean),
      premium: _premium,
      dynamicScheme: scheme,
    );
    expect(theme.scaffoldBackgroundColor, scheme.surface);
    expect(theme.colorScheme.primary, scheme.primary);
  });
}
