import 'package:flutter/material.dart';

/// Semantic colour tokens of the app, exposed as a [ThemeExtension].
///
/// Read them with `context.appColors`. [dark] and [light] hold the design
/// system values; dynamic colour overrides a subset via [copyWith].
@immutable
class AppColors extends ThemeExtension<AppColors> {
  /// Creates a colour set.
  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceRaised,
    required this.outline,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.onAccent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.dangerText,
    required this.onDanger,
    required this.tvRed,
    required this.tvGreen,
    required this.tvYellow,
    required this.tvBlue,
  });

  /// Page background.
  final Color bg;

  /// Cards, dialogs and sheets.
  final Color surface;

  /// Keys and raised controls.
  final Color surfaceRaised;

  /// Borders and dividers.
  final Color outline;

  /// Primary text.
  final Color textPrimary;

  /// Secondary text (at least 4.5:1 on every surface).
  final Color textSecondary;

  /// Accent for interactive elements.
  final Color accent;

  /// Content drawn on top of [accent].
  final Color onAccent;

  /// Success indicator. Non-text use only.
  final Color success;

  /// Warning indicator. Non-text use only.
  final Color warning;

  /// Danger indicator. Non-text use only.
  final Color danger;

  /// Danger colour that is safe as text (at least 4.5:1).
  final Color dangerText;

  /// Content drawn on top of [dangerText].
  final Color onDanger;

  /// Red colour key of the TV remote.
  final Color tvRed;

  /// Green colour key of the TV remote.
  final Color tvGreen;

  /// Yellow colour key of the TV remote.
  final Color tvYellow;

  /// Blue colour key of the TV remote.
  final Color tvBlue;

  /// The dark palette.
  static const AppColors dark = AppColors(
    bg: Color(0xFF0F1115),
    surface: Color(0xFF181B21),
    surfaceRaised: Color(0xFF232731),
    outline: Color(0xFF2E3340),
    textPrimary: Color(0xFFF2F4F8),
    textSecondary: Color(0xFFA7AFBF),
    accent: Color(0xFF6C8CFF),
    onAccent: Color(0xFF0F1115),
    success: Color(0xFF3DDC97),
    warning: Color(0xFFFFC857),
    danger: Color(0xFFFF6B6B),
    dangerText: Color(0xFFFF6B6B),
    onDanger: Color(0xFF0F1115),
    tvRed: Color(0xFFE5484D),
    tvGreen: Color(0xFF30A46C),
    tvYellow: Color(0xFFF5D90A),
    tvBlue: Color(0xFF3E63DD),
  );

  /// The Theater Mode palette: the dark set with an even darker background
  /// and softer text and accent, for a dim room. Text still has at least
  /// 4.5:1 on every surface; the status and TV colours are the dark set's.
  static const AppColors theater = AppColors(
    bg: Color(0xFF000000),
    surface: Color(0xFF050608),
    surfaceRaised: Color(0xFF0D0F13),
    outline: Color(0xFF1A1D24),
    textPrimary: Color(0xFFB8BEC9),
    textSecondary: Color(0xFF8A919E),
    accent: Color(0xFF5A72C8),
    onAccent: Color(0xFF000000),
    success: Color(0xFF3DDC97),
    warning: Color(0xFFFFC857),
    danger: Color(0xFFFF6B6B),
    dangerText: Color(0xFFFF6B6B),
    onDanger: Color(0xFF0F1115),
    tvRed: Color(0xFFE5484D),
    tvGreen: Color(0xFF30A46C),
    tvYellow: Color(0xFFF5D90A),
    tvBlue: Color(0xFF3E63DD),
  );

  /// The light palette.
  static const AppColors light = AppColors(
    bg: Color(0xFFF6F7F9),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFECEEF2),
    outline: Color(0xFFD5D9E0),
    textPrimary: Color(0xFF12151B),
    textSecondary: Color(0xFF4A5263),
    accent: Color(0xFF3D5AFE),
    onAccent: Color(0xFFFFFFFF),
    success: Color(0xFF0F9D63),
    warning: Color(0xFFB7791F),
    danger: Color(0xFFD64545),
    dangerText: Color(0xFFB83A3A),
    onDanger: Color(0xFFFFFFFF),
    tvRed: Color(0xFFE5484D),
    tvGreen: Color(0xFF30A46C),
    tvYellow: Color(0xFFF5D90A),
    tvBlue: Color(0xFF3E63DD),
  );

  @override
  AppColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceRaised,
    Color? outline,
    Color? textPrimary,
    Color? textSecondary,
    Color? accent,
    Color? onAccent,
    Color? success,
    Color? warning,
    Color? danger,
    Color? dangerText,
    Color? onDanger,
    Color? tvRed,
    Color? tvGreen,
    Color? tvYellow,
    Color? tvBlue,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      outline: outline ?? this.outline,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      dangerText: dangerText ?? this.dangerText,
      onDanger: onDanger ?? this.onDanger,
      tvRed: tvRed ?? this.tvRed,
      tvGreen: tvGreen ?? this.tvGreen,
      tvYellow: tvYellow ?? this.tvYellow,
      tvBlue: tvBlue ?? this.tvBlue,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      bg: mix(bg, other.bg),
      surface: mix(surface, other.surface),
      surfaceRaised: mix(surfaceRaised, other.surfaceRaised),
      outline: mix(outline, other.outline),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      danger: mix(danger, other.danger),
      dangerText: mix(dangerText, other.dangerText),
      onDanger: mix(onDanger, other.onDanger),
      tvRed: mix(tvRed, other.tvRed),
      tvGreen: mix(tvGreen, other.tvGreen),
      tvYellow: mix(tvYellow, other.tvYellow),
      tvBlue: mix(tvBlue, other.tvBlue),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppColors &&
      other.bg == bg &&
      other.surface == surface &&
      other.surfaceRaised == surfaceRaised &&
      other.outline == outline &&
      other.textPrimary == textPrimary &&
      other.textSecondary == textSecondary &&
      other.accent == accent &&
      other.onAccent == onAccent &&
      other.success == success &&
      other.warning == warning &&
      other.danger == danger &&
      other.dangerText == dangerText &&
      other.onDanger == onDanger &&
      other.tvRed == tvRed &&
      other.tvGreen == tvGreen &&
      other.tvYellow == tvYellow &&
      other.tvBlue == tvBlue;

  @override
  int get hashCode => Object.hash(
    bg,
    surface,
    surfaceRaised,
    outline,
    textPrimary,
    textSecondary,
    accent,
    onAccent,
    success,
    warning,
    danger,
    dangerText,
    onDanger,
    tvRed,
    tvGreen,
    tvYellow,
    tvBlue,
  );
}

/// Access to the app's colour tokens from a [BuildContext].
extension AppThemeX on BuildContext {
  /// The [AppColors] of the nearest [Theme].
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}

/// Spacing scale on a 4-point grid.
abstract final class AppSpacing {
  /// 4 dp.
  static const double xs = 4;

  /// 8 dp.
  static const double s = 8;

  /// 12 dp.
  static const double m = 12;

  /// 16 dp.
  static const double l = 16;

  /// 24 dp.
  static const double xl = 24;

  /// 32 dp.
  static const double xxl = 32;
}

/// Corner radii.
abstract final class AppRadii {
  /// Remote keys.
  static const double key = 20;

  /// Cards.
  static const double card = 16;

  /// Top corners of sheets and dialogs.
  static const double sheet = 28;
}

/// Minimum interactive sizes.
abstract final class AppSizes {
  /// Minimum size of a remote key.
  static const double keyMin = 56;

  /// Minimum size of any other touch target.
  static const double touchMin = 48;

  /// Minimum gap between keys.
  static const double keyGap = 8;
}

/// Motion durations and curves.
abstract final class AppMotion {
  /// Quick feedback, such as a key press.
  static const Duration fast = Duration(milliseconds: 150);

  /// Default transition.
  static const Duration standard = Duration(milliseconds: 200);

  /// Larger transitions.
  static const Duration slow = Duration(milliseconds: 250);

  /// Default curve.
  static const Curve curve = Curves.easeOut;

  /// Scale applied to a pressed key.
  static const double pressScale = 0.94;
}

/// WCAG contrast ratio between [a] and [b], from 1 to 21.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}
