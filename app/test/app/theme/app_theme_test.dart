import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/theme/app_theme.dart';
import 'package:tv_remote/app/theme/page_transitions.dart';
import 'package:tv_remote/app/theme/tokens.dart';

void main() {
  void expectMapsTokens(Brightness brightness, AppColors c) {
    final t = buildAppTheme(brightness: brightness);
    expect(t.useMaterial3, isTrue);
    expect(t.colorScheme.brightness, brightness);
    expect(t.scaffoldBackgroundColor, c.bg);
    expect(t.colorScheme.primary, c.accent);
    expect(t.colorScheme.secondary, c.accent);
    expect(t.colorScheme.onPrimary, c.onAccent);
    expect(t.colorScheme.onSecondary, c.onAccent);
    expect(t.colorScheme.error, c.dangerText);
    expect(t.colorScheme.onError, c.onDanger);
    expect(t.colorScheme.surface, c.surface);
    expect(t.colorScheme.onSurface, c.textPrimary);
    expect(t.colorScheme.onSurfaceVariant, c.textSecondary);
    expect(t.colorScheme.outline, c.outline);
    expect(t.colorScheme.outlineVariant, c.outline);
    expect(t.colorScheme.surfaceContainerHighest, c.surfaceRaised);
    expect(t.extension<AppColors>(), c);
  }

  test('dark_theme_maps_tokens_to_color_scheme', () {
    expectMapsTokens(Brightness.dark, AppColors.dark);
  });

  test('light_theme_maps_tokens_to_color_scheme', () {
    expectMapsTokens(Brightness.light, AppColors.light);
  });

  test('type_scale_matches_tokens', () {
    final tt = buildAppTheme(brightness: Brightness.light).textTheme;
    void expectStyle(
      TextStyle? style,
      double size,
      double lineHeight,
      FontWeight weight,
    ) {
      expect(style!.fontSize, size);
      expect(style.height! * size, closeTo(lineHeight, 0.01));
      expect(style.fontWeight, weight);
    }

    expectStyle(tt.displaySmall, 28, 34, FontWeight.w600);
    expectStyle(tt.titleLarge, 20, 26, FontWeight.w600);
    expectStyle(tt.bodyLarge, 16, 22, FontWeight.w400);
    expectStyle(tt.labelLarge, 14, 18, FontWeight.w500);
    expectStyle(tt.bodySmall, 12, 16, FontWeight.w400);
  });

  test('text_colours_are_primary_except_body_small_secondary', () {
    final tt = buildAppTheme(brightness: Brightness.dark).textTheme;
    expect(tt.displaySmall!.color, AppColors.dark.textPrimary);
    expect(tt.titleLarge!.color, AppColors.dark.textPrimary);
    expect(tt.bodyLarge!.color, AppColors.dark.textPrimary);
    expect(tt.labelLarge!.color, AppColors.dark.textPrimary);
    expect(tt.bodySmall!.color, AppColors.dark.textSecondary);
  });

  test('dialog_and_sheet_use_surface_and_28dp_radius', () {
    final t = buildAppTheme(brightness: Brightness.dark);
    expect(t.dialogTheme.backgroundColor, AppColors.dark.surface);
    expect(
      (t.dialogTheme.shape! as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(28),
    );
    expect(t.bottomSheetTheme.backgroundColor, AppColors.dark.surface);
    expect(t.bottomSheetTheme.dragHandleColor, AppColors.dark.outline);
    expect(
      (t.bottomSheetTheme.shape! as RoundedRectangleBorder).borderRadius,
      const BorderRadius.vertical(top: Radius.circular(28)),
    );
  });

  test('app_bar_is_flat_on_bg', () {
    final t = buildAppTheme(brightness: Brightness.light);
    expect(t.appBarTheme.backgroundColor, AppColors.light.bg);
    expect(t.appBarTheme.foregroundColor, AppColors.light.textPrimary);
    expect(t.appBarTheme.elevation, 0);
    expect(t.appBarTheme.scrolledUnderElevation, 0);
  });

  test('buttons_have_48dp_minimum_size', () {
    final t = buildAppTheme(brightness: Brightness.dark);
    expect(
      t.filledButtonTheme.style!.minimumSize!.resolve({}),
      const Size(48, 48),
    );
    expect(
      t.textButtonTheme.style!.minimumSize!.resolve({}),
      const Size(48, 48),
    );
  });

  test(
    'dynamic_scheme_replaces_accent_and_surfaces_but_keeps_status_colours',
    () {
      final s = ColorScheme.fromSeed(
        seedColor: const Color(0xFF00FF00),
        brightness: Brightness.dark,
      );
      final t = buildAppTheme(brightness: Brightness.dark, dynamicScheme: s);
      final c = t.extension<AppColors>()!;
      expect(t.colorScheme.primary, s.primary);
      expect(c.accent, s.primary);
      expect(c.onAccent, s.onPrimary);
      expect(c.bg, s.surface);
      expect(c.surface, s.surfaceContainer);
      expect(c.surfaceRaised, s.surfaceContainerHighest);
      expect(c.outline, s.outlineVariant);
      expect(c.textPrimary, s.onSurface);
      expect(c.textSecondary, s.onSurfaceVariant);
      expect(c.success, AppColors.dark.success);
      expect(c.tvRed, AppColors.dark.tvRed);
      expect(t.colorScheme.error, AppColors.dark.dangerText);
      expect(t.colorScheme.onError, AppColors.dark.onDanger);
      expect(t.scaffoldBackgroundColor, c.bg);
    },
  );

  test('dynamic_scheme_text_secondary_contrast_at_least_4_5', () {
    for (final seed in const [
      Color(0xFFFF0000),
      Color(0xFF00FF00),
      Color(0xFFFFFF00),
      Color(0xFF0000FF),
    ]) {
      for (final b in Brightness.values) {
        final c = buildAppTheme(
          brightness: b,
          dynamicScheme: ColorScheme.fromSeed(seedColor: seed, brightness: b),
        ).extension<AppColors>()!;
        expect(contrastRatio(c.textSecondary, c.bg), greaterThanOrEqualTo(4.5));
      }
    }
  });

  test('every_platform_uses_the_reduce_motion_page_builder', () {
    for (final theme in [
      buildAppTheme(brightness: Brightness.light),
      buildAppTheme(brightness: Brightness.dark),
      buildAppTheme(
        brightness: Brightness.dark,
        dynamicScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00FF00),
          brightness: Brightness.dark,
        ),
      ),
      buildTheaterTheme(),
    ]) {
      final builders = theme.pageTransitionsTheme.builders;
      for (final platform in TargetPlatform.values) {
        expect(
          builders[platform],
          isA<AppPageTransitionsBuilder>(),
          reason: '$platform',
        );
      }
      PageTransitionsBuilder innerOf(TargetPlatform p) =>
          (builders[p]! as AppPageTransitionsBuilder).inner;
      expect(
        innerOf(TargetPlatform.android),
        isA<PredictiveBackPageTransitionsBuilder>(),
      );
      expect(
        innerOf(TargetPlatform.iOS),
        isA<CupertinoPageTransitionsBuilder>(),
      );
      expect(
        innerOf(TargetPlatform.macOS),
        isA<CupertinoPageTransitionsBuilder>(),
      );
      for (final p in const [
        TargetPlatform.fuchsia,
        TargetPlatform.linux,
        TargetPlatform.windows,
      ]) {
        expect(innerOf(p), isA<FadeForwardsPageTransitionsBuilder>());
      }
      // The ripple is on until reduce motion takes it away.
      expect(theme.splashFactory, isNot(NoSplash.splashFactory));
    }
  });

  test('reduced_motion_theme_has_no_splash_and_instant_pages', () {
    final theme = withReducedMotion(
      buildAppTheme(brightness: Brightness.light),
    );
    expect(theme.splashFactory, NoSplash.splashFactory);
    for (final platform in TargetPlatform.values) {
      final builder = theme.pageTransitionsTheme.builders[platform];
      expect(builder, isA<AppPageTransitionsBuilder>(), reason: '$platform');
      expect(builder!.transitionDuration, Duration.zero, reason: '$platform');
      expect(
        builder.reverseTransitionDuration,
        Duration.zero,
        reason: '$platform',
      );
    }
  });
}
