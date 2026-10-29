import 'package:flutter/material.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';
import 'package:tv_remote/features/apps/presentation/widgets/app_tile.dart';

/// A shortcut to one TV app: its [AppIconSquare] (a monogram or the icon the
/// user picked), with the app's name below.
///
/// It never draws a logo. The tile is [widthOf] dp wide: [width] at ordinary
/// text sizes, wider for large text, whose name then takes [nameLinesOf]
/// lines (Ruling P7-R11). When [isCurrent], a [NowOnTvDot] marks the square
/// and the spoken label says the app is on the TV now. While the square is
/// pressed it scales to [AppMotion.pressScale] (Ruling P7-R5).
class QuickAppTile extends StatefulWidget {
  /// Creates a tile for [app].
  const QuickAppTile({
    required this.app,
    required this.isCurrent,
    required this.onTap,
    super.key,
  });

  /// Width of a tile at ordinary text sizes, and its minimum.
  static const double width = 72;

  /// The widest a tile grows for large text.
  static const double maxWidth = 112;

  /// Side of the monogram square.
  static const double squareSize = kAppSquareSize;

  /// Text grown past this factor of its base size is large text: the name
  /// takes two lines and the tile grows.
  static const double _largeText = 1.3;

  /// The app this tile opens.
  final AppEntry app;

  /// Whether [app] is the app open on the TV right now.
  final bool isCurrent;

  /// Called when the tile is tapped.
  final VoidCallback onTap;

  static TextStyle _nameStyle(BuildContext context) =>
      Theme.of(context).textTheme.labelSmall!;

  /// The name's font size at the ambient text scale, over its base size.
  static double _growth(BuildContext context) {
    final base = _nameStyle(context).fontSize ?? 11;
    return MediaQuery.textScalerOf(context).scale(base) / base;
  }

  /// The lines a name may take at the ambient text scale: 1, or 2 for large
  /// text.
  static int nameLinesOf(BuildContext context) =>
      _growth(context) > _largeText ? 2 : 1;

  /// The width of a tile at the ambient text scale: [width], growing with
  /// large text up to [maxWidth].
  static double widthOf(BuildContext context) =>
      (width * _growth(context) / _largeText).clamp(width, maxWidth);

  /// The height of a tile at the ambient text scale, so a horizontal list of
  /// tiles can give itself a bounded height: the square, a gap and
  /// [nameLinesOf] lines of the name.
  static double heightOf(BuildContext context) {
    final style = _nameStyle(context);
    // Scale the font size, then apply the line height: that is what the
    // text does. Scaling the finished line would be wrong for a non-linear
    // scaler (Android 14's curve grows small sizes more than large ones).
    final line =
        MediaQuery.textScalerOf(context).scale(style.fontSize ?? 11) *
        (style.height ?? 1.5);
    return squareSize +
        AppSpacing.xs +
        nameLinesOf(context) * line.ceilToDouble();
  }

  @override
  State<QuickAppTile> createState() => _QuickAppTileState();
}

class _QuickAppTileState extends State<QuickAppTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final app = widget.app;
    final isCurrent = widget.isCurrent;
    final onTap = widget.onTap;

    return Semantics(
      button: true,
      label: isCurrent
          ? l10n.quickAppNowOnTv(app.name)
          : l10n.quickAppOpen(app.name),
      excludeSemantics: true,
      onTap: onTap,
      child: SizedBox(
        width: QuickAppTile.widthOf(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.xs,
          children: [
            AnimatedScale(
              scale: _pressed ? AppMotion.pressScale : 1,
              duration: AppMotion.durationOf(context, AppMotion.fast),
              curve: AppMotion.curve,
              child: SizedBox.square(
                key: const ValueKey('quick_app_square'),
                dimension: QuickAppTile.squareSize,
                child: Stack(
                  children: [
                    Positioned.fill(child: AppIconSquare(app: app)),
                    // The ink of a tap draws over the square.
                    Positioned.fill(
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          onTap: onTap,
                          onHighlightChanged: (pressed) =>
                              setState(() => _pressed = pressed),
                          borderRadius: BorderRadius.circular(AppRadii.key),
                        ),
                      ),
                    ),
                    if (isCurrent)
                      // The ring grows around the dot, which stays where it
                      // was.
                      PositionedDirectional(
                        top: AppSpacing.s - NowOnTvDot.ringWidth,
                        end: AppSpacing.s - NowOnTvDot.ringWidth,
                        child: NowOnTvDot(
                          ringColor: appSquareInk(context, app),
                          dotKey: const ValueKey('quick_app_current_dot'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Text(
                app.name,
                maxLines: QuickAppTile.nameLinesOf(context),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: text.labelSmall?.copyWith(color: colors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
