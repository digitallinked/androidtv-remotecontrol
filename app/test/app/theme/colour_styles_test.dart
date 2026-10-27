import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/app/theme/app_theme.dart';
import 'package:tv_remote/app/theme/colour_styles.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/core/purchases/premium.dart';
import 'package:tv_remote/core/storage/settings_store.dart';

const _premium = PremiumState(isPremium: true, known: true);

/// The settings of a phone where [style] was chosen.
Future<AppSettings> _settingsWith(ColourStyle style) async {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  final store = await SettingsStore.open();
  await store.setColourStyle(style);
  return store.snapshot();
}

void main() {
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
