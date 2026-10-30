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

/// [theme] for a user who asked for reduced motion (Rulings P7-R4, P7-C1,
/// P7-C5): no ink ripple and no pressed ink highlight anywhere, and pages
/// that change in one frame. Everything else, colours included, is
/// [theme]'s.
///
/// Flutter fades a pressed highlight in and out over 200 ms whatever the
/// reduce-motion flag says, and offers no way to shorten it. So the pressed
/// highlight is made transparent: `highlightColor` for list tiles and plain
/// ink wells, and the pressed overlay of every button theme. Hover and focus
/// highlights are kept: they aren't motion a press starts, and focus is how a
/// keyboard user finds their place. A press still shows its result (a page,
/// a sheet, a toggled switch), and the remote's keys still scale at once.
ThemeData withReducedMotion(ThemeData theme) => theme.copyWith(
  splashFactory: NoSplash.splashFactory,
  highlightColor: Colors.transparent,
  pageTransitionsTheme: instantPageTransitionsTheme,
  filledButtonTheme: FilledButtonThemeData(
    style: _noPressedOverlay(theme.filledButtonTheme.style),
  ),
  textButtonTheme: TextButtonThemeData(
    style: _noPressedOverlay(theme.textButtonTheme.style),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: _noPressedOverlay(theme.outlinedButtonTheme.style),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: _noPressedOverlay(theme.elevatedButtonTheme.style),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: _noPressedOverlay(theme.iconButtonTheme.style),
  ),
);

/// [style] whose overlay is transparent while pressed, and whose shape,
/// colour and elevation changes don't animate. Other states keep the
/// overlay [style] gives, or the button's default when it gives none.
ButtonStyle _noPressedOverlay(ButtonStyle? style) {
  final overlay = style?.overlayColor;
  return (style ?? const ButtonStyle()).copyWith(
    overlayColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.pressed)
          ? Colors.transparent
          : overlay?.resolve(states),
    ),
    animationDuration: Duration.zero,
  );
}

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
