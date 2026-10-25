import 'package:flutter/material.dart';
import 'package:tv_remote/app/theme/tokens.dart';

/// Builds the app [ThemeData] for [brightness] from the design tokens.
///
/// When [dynamicScheme] is given (Material You), its colours replace the
/// accent and surface tokens; status and TV-key colours always come from the
/// tokens, and `error` keeps the accessible danger-text token.
ThemeData buildAppTheme({
  required Brightness brightness,
  ColorScheme? dynamicScheme,
}) {
  final base = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final s = dynamicScheme;
  final t = s == null
      ? base
      : base.copyWith(
          bg: s.surface,
          surface: s.surfaceContainer,
          surfaceRaised: s.surfaceContainerHighest,
          outline: s.outlineVariant,
          textPrimary: s.onSurface,
          textSecondary: s.onSurfaceVariant,
          accent: s.primary,
          onAccent: s.onPrimary,
        );

  final colorScheme = s == null
      ? ColorScheme(
          brightness: brightness,
          primary: t.accent,
          onPrimary: t.onAccent,
          secondary: t.accent,
          onSecondary: t.onAccent,
          error: t.dangerText,
          onError: t.onDanger,
          surface: t.surface,
          onSurface: t.textPrimary,
          onSurfaceVariant: t.textSecondary,
          outline: t.outline,
          outlineVariant: t.outline,
          surfaceContainerHighest: t.surfaceRaised,
        )
      : s.copyWith(error: base.dangerText, onError: base.onDanger);

  const sheetShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
  );
  const buttonSize = WidgetStatePropertyAll(
    Size(AppSizes.touchMin, AppSizes.touchMin),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: t.bg,
    textTheme: _textTheme(t),
    dialogTheme: DialogThemeData(
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.sheet),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.surface,
      shape: sheetShape,
      dragHandleColor: t.outline,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: t.bg,
      foregroundColor: t.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    filledButtonTheme: const FilledButtonThemeData(
      style: ButtonStyle(minimumSize: buttonSize),
    ),
    textButtonTheme: const TextButtonThemeData(
      style: ButtonStyle(minimumSize: buttonSize),
    ),
    extensions: [t],
  );
}

TextStyle _style(
  double size,
  double lineHeight,
  FontWeight weight,
  Color color,
) => TextStyle(
  fontSize: size,
  height: lineHeight / size,
  fontWeight: weight,
  color: color,
);

TextTheme _textTheme(AppColors t) => TextTheme(
  displaySmall: _style(28, 34, FontWeight.w600, t.textPrimary),
  titleLarge: _style(20, 26, FontWeight.w600, t.textPrimary),
  bodyLarge: _style(16, 22, FontWeight.w400, t.textPrimary),
  labelLarge: _style(14, 18, FontWeight.w500, t.textPrimary),
  bodySmall: _style(12, 16, FontWeight.w400, t.textSecondary),
);
