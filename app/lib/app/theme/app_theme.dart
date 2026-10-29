import 'package:flutter/material.dart';
import 'package:tv_remote/app/theme/page_transitions.dart';
import 'package:tv_remote/app/theme/tokens.dart';

/// Builds the app [ThemeData] for [brightness] from the design tokens.
///
/// When [dynamicScheme] is given (Material You), its colours replace the
/// accent and surface tokens; status and TV-key colours always come from the
/// tokens, and `error` keeps the accessible danger-text token.
///
/// [colours] replaces the base palette (a colour style); the tokens that
/// [dynamicScheme] overrides still come from the scheme.
ThemeData buildAppTheme({
  required Brightness brightness,
  ColorScheme? dynamicScheme,
  AppColors? colours,
}) => _buildTheme(
  brightness: brightness,
  base:
      colours ??
      (brightness == Brightness.dark ? AppColors.dark : AppColors.light),
  dynamicScheme: dynamicScheme,
);

/// The theme of Theater Mode: the dark theme on the [AppColors.theater]
/// palette (and a matching `ColorScheme`). Never follows dynamic colour.
ThemeData buildTheaterTheme() => _buildTheme(
  brightness: Brightness.dark,
  base: AppColors.theater,
  dynamicScheme: null,
);

/// [theme] for a user who asked for reduced motion (Rulings P7-R4, P7-C1):
/// no ink ripple anywhere, and pages that change in one frame. Everything
/// else, colours included, is [theme]'s.
ThemeData withReducedMotion(ThemeData theme) => theme.copyWith(
  splashFactory: NoSplash.splashFactory,
  pageTransitionsTheme: instantPageTransitionsTheme,
);

/// Applies [withReducedMotion] to the ambient theme below it while
/// `MediaQuery.disableAnimationsOf` is set, and passes the theme on unchanged
/// otherwise.
///
/// The app shell puts it around the navigator, so every page, sheet and
/// dialog of the app gets it, whichever colour style or brightness is in use.
/// The tree below keeps its shape when the setting changes, so no state is
/// lost.
class ReduceMotionTheme extends StatelessWidget {
  /// Creates the wrapper around [child].
  const ReduceMotionTheme({required this.child, super.key});

  /// The part of the app the rule applies to.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: MediaQuery.disableAnimationsOf(context)
          ? withReducedMotion(theme)
          : theme,
      child: child,
    );
  }
}

ThemeData _buildTheme({
  required Brightness brightness,
  required AppColors base,
  required ColorScheme? dynamicScheme,
}) {
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
    pageTransitionsTheme: appPageTransitionsTheme,
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
