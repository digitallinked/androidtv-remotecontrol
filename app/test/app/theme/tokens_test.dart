import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/theme/tokens.dart';

void main() {
  for (final (name, c) in [
    ('dark', AppColors.dark),
    ('light', AppColors.light),
  ]) {
    test('text_secondary_contrast_at_least_4_5 ($name)', () {
      for (final bg in [c.bg, c.surface, c.surfaceRaised]) {
        expect(contrastRatio(c.textSecondary, bg), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(c.textPrimary, bg), greaterThanOrEqualTo(4.5));
      }
    });
    test('accent_and_danger_text_contrast_at_least_4_5 ($name)', () {
      for (final bg in [c.bg, c.surface]) {
        expect(contrastRatio(c.accent, bg), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(c.dangerText, bg), greaterThanOrEqualTo(4.5));
      }
      expect(contrastRatio(c.onAccent, c.accent), greaterThanOrEqualTo(4.5));
      expect(
        contrastRatio(c.onDanger, c.dangerText),
        greaterThanOrEqualTo(4.5),
      );
    });
    test('status_colours_have_3_to_1_non_text_contrast ($name)', () {
      for (final s in [c.success, c.warning, c.danger]) {
        for (final bg in [c.bg, c.surface]) {
          expect(contrastRatio(s, bg), greaterThanOrEqualTo(3));
        }
      }
    });
  }

  test('token_values_match_design_system', () {
    expect(AppColors.dark.bg, const Color(0xFF0F1115));
    expect(AppColors.light.textSecondary, const Color(0xFF4A5263));
    expect(AppColors.light.dangerText, const Color(0xFFB83A3A));
    expect(AppColors.dark.onAccent, const Color(0xFF0F1115));
    expect(AppColors.light.tvYellow, const Color(0xFFF5D90A));
    expect((AppRadii.key, AppRadii.card, AppRadii.sheet), (20.0, 16.0, 28.0));
    expect(
      (AppSizes.keyMin, AppSizes.touchMin, AppSizes.keyGap),
      (
        56.0,
        48.0,
        8.0,
      ),
    );
    expect(AppMotion.pressScale, 0.94);
  });

  test(
    'contrast_ratio_of_black_on_white_is_21',
    () => expect(
      contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
      closeTo(21, 0.01),
    ),
  );

  test('copy_with_replaces_only_given_fields', () {
    final c = AppColors.dark.copyWith(accent: const Color(0xFF123456));
    expect(c.accent, const Color(0xFF123456));
    expect(c.bg, AppColors.dark.bg);
    expect(c.tvBlue, AppColors.dark.tvBlue);
  });

  test('lerp_interpolates_every_field_and_handles_foreign_type', () {
    expect(AppColors.dark.lerp(AppColors.light, 0), AppColors.dark);
    expect(AppColors.dark.lerp(AppColors.light, 1), AppColors.light);
    final mid = AppColors.dark.lerp(AppColors.light, 0.5);
    expect(mid.bg, Color.lerp(AppColors.dark.bg, AppColors.light.bg, 0.5));
    expect(AppColors.dark.lerp(null, 0.5), AppColors.dark);
  });

  test('motion_durations_match_design_system', () {
    expect(AppMotion.fast, const Duration(milliseconds: 150));
    expect(AppMotion.standard, const Duration(milliseconds: 200));
    expect(AppMotion.slow, const Duration(milliseconds: 250));
    expect(AppMotion.curve, Curves.easeOut);
  });

  test('spacing_follows_4pt_grid', () {
    expect(
      [
        AppSpacing.xs,
        AppSpacing.s,
        AppSpacing.m,
        AppSpacing.l,
        AppSpacing.xl,
        AppSpacing.xxl,
      ],
      [4.0, 8.0, 12.0, 16.0, 24.0, 32.0],
    );
  });

  testWidgets('app_colors_extension_is_read_from_context', (tester) async {
    late AppColors read;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [AppColors.light]),
        home: Builder(
          builder: (context) {
            read = context.appColors;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(read, AppColors.light);
  });
}
