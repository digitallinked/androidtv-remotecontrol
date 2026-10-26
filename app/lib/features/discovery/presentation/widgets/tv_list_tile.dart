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
    return ListTile(
      minTileHeight: AppSizes.keyMin,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      leading: ExcludeSemantics(
        child: Icon(Icons.tv, color: colors.textSecondary),
      ),
      title: Text(tv.displayName),
      subtitle: Text(tv.host),
      // Capped so a long label wraps at large text sizes instead of
      // squeezing the name.
      trailing: label == null
          ? null
          : ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 112),
              child: Text(
                label,
                textAlign: TextAlign.end,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
      onTap: onTap,
    );
  }
}
