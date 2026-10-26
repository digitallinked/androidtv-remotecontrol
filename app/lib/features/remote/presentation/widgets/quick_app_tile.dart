import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';

/// A shortcut to one TV app: a monogram on a raised square, with the app's
/// name below.
///
/// It draws the first letter of the name, never a logo. The tile is [width]
/// dp wide. When [isCurrent], an accent dot marks the square and the spoken
/// label says the app is on the TV now.
class QuickAppTile extends StatelessWidget {
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
  static const double squareSize = 56;

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
    final line = (style.fontSize ?? 11) * (style.height ?? 1.5);
    final scaled = MediaQuery.textScalerOf(context).scale(line);
    return squareSize + AppSpacing.xs + math.max(scaled, line).ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final letter = app.name.isEmpty ? '' : app.name.characters.first;

    return Semantics(
      button: true,
      label: isCurrent
          ? l10n.quickAppNowOnTv(app.name)
          : l10n.quickAppOpen(app.name),
      excludeSemantics: true,
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.xs,
          children: [
            SizedBox.square(
              key: const ValueKey('quick_app_square'),
              dimension: squareSize,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Material(
                      color: colors.surfaceRaised,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.key),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: onTap,
                        child: Center(
                          child: Text(
                            letter,
                            style: text.titleLarge?.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (isCurrent)
                    Positioned(
                      top: AppSpacing.s,
                      right: AppSpacing.s,
                      child: Container(
                        key: const ValueKey('quick_app_current_dot'),
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
