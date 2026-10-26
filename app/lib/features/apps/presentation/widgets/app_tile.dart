import 'package:flutter/material.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';
import 'package:tv_remote/features/apps/domain/shortcut_style.dart';
import 'package:tv_remote/features/remote/presentation/widgets/quick_access_row.dart';

/// The side of the square on every app tile, in dp.
const double kAppSquareSize = 56;

/// The rounded square that stands for an app: its colour and its icon or
/// monogram, and nothing else (no logo; Ruling P5-R4).
///
/// An entry the user styled draws its [AppEntry.customColor] with readable
/// ink and its [AppEntry.customIcon] (an unknown id draws the generic app
/// icon). Any other entry is a monogram, the first letter of its name in upper
/// case, on the raised surface.
///
/// It is left out of semantics: the tile that holds it carries the label.
class AppIconSquare extends StatelessWidget {
  /// Creates the square for [app], [size] dp on a side.
  const AppIconSquare({
    required this.app,
    this.size = kAppSquareSize,
    super.key,
  });

  /// The app to draw.
  final AppEntry app;

  /// The side of the square.
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final custom = app.customColor;
    final fill = custom ?? colors.surfaceRaised;
    final ink = custom == null
        ? colors.textPrimary
        : colourKeyLabelColor(custom);
    final iconId = app.customIcon;
    final Widget content;
    if (iconId != null) {
      content = Icon(
        kShortcutIcons[iconId] ?? Icons.apps,
        size: size / 2,
        color: ink,
      );
    } else {
      final base = Theme.of(context).textTheme.titleLarge;
      final scale = size / kAppSquareSize;
      // The first grapheme, so an accent or an emoji stays whole.
      final letter = app.name.isEmpty
          ? ''
          : app.name.characters.first.toUpperCase();
      content = Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        // The letter grows with the text size but never past its square.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            letter,
            style: base?.copyWith(
              color: ink,
              fontSize: (base.fontSize ?? 20) * scale,
            ),
          ),
        ),
      );
    }
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: fill,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.key),
            ),
          ),
          child: Center(child: content),
        ),
      ),
    );
  }
}

/// One app in the Apps screen's grid: its square over its name.
///
/// It fills the grid cell and the whole tile is one button. The name takes up
/// to two lines. [AppTile.heightOf] is the cell height that holds both lines
/// at the ambient text size. When [isCurrent], an accent dot marks the square
/// and the spoken label says the app is on the TV now.
class AppTile extends StatelessWidget {
  /// Creates a tile for [app].
  const AppTile({
    required this.app,
    required this.isCurrent,
    required this.onTap,
    super.key,
  });

  /// Diameter of the "now on TV" dot.
  static const double dotSize = 8;

  /// Lines the name may take.
  static const int nameLines = 2;

  /// The app this tile opens.
  final AppEntry app;

  /// Whether [app] is the app open on the TV right now.
  final bool isCurrent;

  /// Called when the tile is tapped.
  final VoidCallback onTap;

  /// The height of a grid cell at the ambient text scale: the padding, the
  /// square, a gap and [nameLines] lines of the name.
  static double heightOf(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium!;
    // Scale the font size, then apply the line height: that is what the text
    // does. Scaling the finished line would be wrong for a non-linear scaler.
    final line =
        MediaQuery.textScalerOf(context).scale(style.fontSize ?? 12) *
        (style.height ?? 1.5);
    return 2 * AppSpacing.xs +
        kAppSquareSize +
        AppSpacing.xs +
        nameLines * line.ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: isCurrent
          ? l10n.quickAppNowOnTv(app.name)
          : l10n.quickAppOpen(app.name),
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.key),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Column(
              spacing: AppSpacing.xs,
              children: [
                Stack(
                  children: [
                    AppIconSquare(app: app),
                    if (isCurrent)
                      PositionedDirectional(
                        top: AppSpacing.s,
                        end: AppSpacing.s,
                        child: Container(
                          key: const ValueKey('app_tile_current_dot'),
                          width: dotSize,
                          height: dotSize,
                          decoration: BoxDecoration(
                            color: colors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                Text(
                  app.name,
                  maxLines: nameLines,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: text.labelMedium?.copyWith(color: colors.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
