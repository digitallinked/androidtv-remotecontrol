import 'package:flutter/material.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';
import 'package:tv_remote/features/apps/presentation/widgets/app_tile.dart';

/// A shortcut to one TV app: its [AppIconSquare] (a monogram or the icon the
/// user picked), with the app's name below.
///
/// It never draws a logo. The tile is [width]
/// dp wide. When [isCurrent], an accent dot marks the square and the spoken
/// label says the app is on the TV now. While the square is pressed it scales
/// to [AppMotion.pressScale] (Ruling P7-R5).
class QuickAppTile extends StatefulWidget {
  /// Creates a tile for [app].
  const QuickAppTile({
    required this.app,
    required this.isCurrent,
    required this.onTap,
    super.key,
  });

  /// Width of a tile.
  static const double width = 72;

  /// Side of the monogram square.
  static const double squareSize = kAppSquareSize;

  /// Diameter of the "now on TV" dot.
  static const double dotSize = 8;

  /// The app this tile opens.
  final AppEntry app;

  /// Whether [app] is the app open on the TV right now.
  final bool isCurrent;

  /// Called when the tile is tapped.
  final VoidCallback onTap;

  /// The height of a tile at the ambient text scale, so a horizontal list of
  /// tiles can give itself a bounded height.
  static double heightOf(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall!;
    // Scale the font size, then apply the line height: that is what the
    // text does. Scaling the finished line would be wrong for a non-linear
    // scaler (Android 14's curve grows small sizes more than large ones).
    final line =
        MediaQuery.textScalerOf(context).scale(style.fontSize ?? 11) *
        (style.height ?? 1.5);
    return squareSize + AppSpacing.xs + line.ceilToDouble();
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
        width: QuickAppTile.width,
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
                      PositionedDirectional(
                        top: AppSpacing.s,
                        end: AppSpacing.s,
                        child: Container(
                          key: const ValueKey('quick_app_current_dot'),
                          width: QuickAppTile.dotSize,
                          height: QuickAppTile.dotSize,
                          decoration: BoxDecoration(
                            color: colors.accent,
                            shape: BoxShape.circle,
                          ),
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
                maxLines: 1,
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
