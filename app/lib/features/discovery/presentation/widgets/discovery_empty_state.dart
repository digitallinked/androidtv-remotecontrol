import 'package:flutter/material.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';

/// What the discovery screen shows when the search found nothing, or failed.
/// Both come with the actions to scan again and to get help.
class DiscoveryEmptyState extends StatelessWidget {
  /// Creates the empty state. [failed] swaps the "no TVs" copy for the
  /// "couldn't search" copy.
  const DiscoveryEmptyState({
    required this.failed,
    required this.onScanAgain,
    required this.onTroubleshooting,
    super.key,
  });

  /// Whether the search itself failed.
  final bool failed;

  /// Called by the "Scan again" button.
  final VoidCallback onScanAgain;

  /// Called by the "Troubleshooting" button.
  final VoidCallback onTroubleshooting;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.appColors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.m,
          children: [
            ExcludeSemantics(
              child: Icon(
                failed ? Icons.wifi_off : Icons.tv_outlined,
                size: 48,
                color: colors.textSecondary,
              ),
            ),
            Text(
              failed ? l10n.discoverErrorTitle : l10n.discoverEmptyTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            Text(
              failed ? l10n.discoverErrorBody : l10n.discoverEmptyBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            FilledButton(
              onPressed: onScanAgain,
              child: Text(l10n.discoverScanAgain),
            ),
            TextButton(
              onPressed: onTroubleshooting,
              child: Text(l10n.discoverTroubleshooting),
            ),
          ],
        ),
      ),
    );
  }
}
