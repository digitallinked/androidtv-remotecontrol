import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';

/// One TV in the discovery list.
class TvListTile extends StatelessWidget {
  /// Creates a tile for [tv]. [isPaired] adds the "Paired" label; a legacy
  /// TV shows "Update needed" instead.
  const TvListTile({
    required this.tv,
    required this.isPaired,
    required this.onTap,
    super.key,
  });

  /// The TV to show.
  final DiscoveredTv tv;

  /// Whether this phone is already paired with the TV.
  final bool isPaired;

  /// Called when the tile is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.appColors;
    final label = tv.isLegacyService
        ? l10n.discoverUpdateNeeded
        : (isPaired ? l10n.discoverPaired : null);
    // Built like a Material 3 list tile, but as a row whose height follows
    // its tallest part: a ListTile caps its trailing slot's height, which
    // cut a wrapped label at large text sizes (Ruling P9-C6).
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.keyMin),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.s,
          ),
          child: Row(
            spacing: AppSpacing.l,
            children: [
              ExcludeSemantics(
                child: Icon(Icons.tv, color: colors.textSecondary),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // One line at any text size: a long name ends in an
                    // ellipsis, and a screen reader still reads it in full.
                    Text(
                      tv.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      tv.host,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Capped so a long label wraps at large text sizes instead of
              // squeezing the name; the row grows to fit it.
              if (label != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 112),
                  child: Text(
                    label,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
