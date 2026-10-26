import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/theme/app_theme.dart';
import 'package:tv_remote/app/theme/tokens.dart';

void main() {
  const c = AppColors.theater;

  test('theater_palette_text_contrast_at_least_4_5', () {
    for (final bg in [c.bg, c.surface, c.surfaceRaised]) {
      expect(contrastRatio(c.textPrimary, bg), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(c.textSecondary, bg), greaterThanOrEqualTo(4.5));
    }
  });

  test('theater_palette_accent_is_readable_and_has_readable_content', () {
    for (final bg in [c.bg, c.surface]) {
      expect(contrastRatio(c.accent, bg), greaterThanOrEqualTo(4.5));
    }
    expect(contrastRatio(c.onAccent, c.accent), greaterThanOrEqualTo(4.5));
  });

  test('theater_palette_is_darker_than_the_dark_palette', () {
    const dark = AppColors.dark;
    expect(c.bg.computeLuminance(), lessThan(dark.bg.computeLuminance()));
    expect(
      c.surfaceRaised.computeLuminance(),
      lessThan(dark.surfaceRaised.computeLuminance()),
    );
    expect(
      c.textPrimary.computeLuminance(),
      lessThan(dark.textPrimary.computeLuminance()),
    );
  });

  test('theater_palette_values_and_shared_status_colours', () {
    expect(c.bg, const Color(0xFF000000));
    expect(c.surface, const Color(0xFF050608));
    expect(c.surfaceRaised, const Color(0xFF0D0F13));
    expect(c.outline, const Color(0xFF1A1D24));
    expect(c.textPrimary, const Color(0xFFB8BEC9));
    expect(c.textSecondary, const Color(0xFF8A919E));
    expect(c.accent, const Color(0xFF5A72C8));
    expect(c.onAccent, const Color(0xFF000000));
    // Status and TV colours are the dark set's.
    final carried = AppColors.dark.copyWith(
      bg: c.bg,
      surface: c.surface,
      surfaceRaised: c.surfaceRaised,
      outline: c.outline,
      textPrimary: c.textPrimary,
      textSecondary: c.textSecondary,
      accent: c.accent,
      onAccent: c.onAccent,
    );
    expect(c, carried);
  });

  test('theater_theme_is_dark_with_the_theater_extension', () {
    final theme = buildTheaterTheme();
    expect(theme.brightness, Brightness.dark);
    expect(theme.extension<AppColors>(), AppColors.theater);
    expect(theme.scaffoldBackgroundColor, c.bg);
    expect(theme.colorScheme.surface, c.surface);
    expect(theme.colorScheme.primary, c.accent);
    expect(theme.colorScheme.onSurface, c.textPrimary);
    expect(theme.appBarTheme.backgroundColor, c.bg);
  });
}
