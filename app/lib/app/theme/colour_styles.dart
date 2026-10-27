import 'package:flutter/material.dart';
import 'package:tv_remote/app/theme/app_theme.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/core/purchases/premium.dart';
import 'package:tv_remote/core/storage/settings_store.dart';

/// The palette of [style] for [brightness] (Ruling P6-R12).
///
/// [ColourStyle.standard] is the app's own palette, unchanged. A premium style
/// replaces the background, surface, outline, text and accent tokens; status,
/// danger and TV-key colours always stay the app's, so a style never changes
/// what a colour means. Every text and accent pair has at least 4.5:1.
AppColors colourStyleColors(ColourStyle style, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final base = dark ? AppColors.dark : AppColors.light;
  return switch (style) {
    ColourStyle.standard => base,
    ColourStyle.ocean =>
      dark
          ? base.copyWith(
              bg: const Color(0xFF0B1418),
              surface: const Color(0xFF101D22),
              surfaceRaised: const Color(0xFF18282E),
              outline: const Color(0xFF24383F),
              textPrimary: const Color(0xFFEFF6F7),
              textSecondary: const Color(0xFF9FB4B9),
              accent: const Color(0xFF3FC6C6),
              onAccent: const Color(0xFF06181A),
            )
          : base.copyWith(
              bg: const Color(0xFFF3F8F8),
              surface: const Color(0xFFFFFFFF),
              surfaceRaised: const Color(0xFFE4EFEF),
              outline: const Color(0xFFC9DADB),
              textPrimary: const Color(0xFF0E1A1C),
              textSecondary: const Color(0xFF44575A),
              accent: const Color(0xFF00777A),
              onAccent: const Color(0xFFFFFFFF),
            ),
    ColourStyle.ember =>
      dark
          ? base.copyWith(
              bg: const Color(0xFF16110D),
              surface: const Color(0xFF1F1813),
              surfaceRaised: const Color(0xFF2B221B),
              outline: const Color(0xFF3B2F25),
              textPrimary: const Color(0xFFF8F2EC),
              textSecondary: const Color(0xFFBFAF9F),
              accent: const Color(0xFFFF9F43),
              onAccent: const Color(0xFF1A0F05),
            )
          : base.copyWith(
              bg: const Color(0xFFFAF6F2),
              surface: const Color(0xFFFFFFFF),
              surfaceRaised: const Color(0xFFF1E9E1),
              outline: const Color(0xFFE0D3C6),
              textPrimary: const Color(0xFF1D1610),
              textSecondary: const Color(0xFF5E4E40),
              accent: const Color(0xFFB34D00),
              onAccent: const Color(0xFFFFFFFF),
            ),
    ColourStyle.midnight =>
      dark
          ? base.copyWith(
              bg: const Color(0xFF000000),
              surface: const Color(0xFF0A0A0F),
              surfaceRaised: const Color(0xFF16161F),
              outline: const Color(0xFF262633),
              textPrimary: const Color(0xFFF1F0F7),
              textSecondary: const Color(0xFFA9A6BD),
              accent: const Color(0xFFA98BFF),
              onAccent: const Color(0xFF120A26),
            )
          : base.copyWith(
              bg: const Color(0xFFF5F4FA),
              surface: const Color(0xFFFFFFFF),
              surfaceRaised: const Color(0xFFEAE8F3),
              outline: const Color(0xFFD4D1E3),
              textPrimary: const Color(0xFF14121D),
              textSecondary: const Color(0xFF4E4A63),
              accent: const Color(0xFF5B3FD1),
              onAccent: const Color(0xFFFFFFFF),
            ),
  };
}

/// The style the app shows (Ruling P6-R12): the stored one for a Premium
/// user, else [ColourStyle.standard].
///
/// Losing Premium doesn't clear the stored choice, so it returns with
/// Premium. Colours from the wallpaper win over any style; the caller checks
/// that, because only it knows whether the phone supplied a scheme.
ColourStyle effectiveColourStyle({
  required AppSettings settings,
  required PremiumState premium,
}) => premium.isPremium ? settings.colourStyle : ColourStyle.standard;

/// The app theme for [brightness] under the user's [settings].
///
/// A [dynamicScheme] (colours from the wallpaper, when switched on and
/// supplied by the phone) wins over a colour style; otherwise the style that
/// [effectiveColourStyle] gives is used.
ThemeData buildSettingsTheme({
  required Brightness brightness,
  required AppSettings settings,
  required PremiumState premium,
  ColorScheme? dynamicScheme,
}) => buildAppTheme(
  brightness: brightness,
  dynamicScheme: dynamicScheme,
  colours: dynamicScheme == null
      ? colourStyleColors(
          effectiveColourStyle(settings: settings, premium: premium),
          brightness,
        )
      : null,
);
