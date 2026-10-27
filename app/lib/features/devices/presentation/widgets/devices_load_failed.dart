import 'package:flutter/material.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';

/// The saved TVs couldn't be read: says so, with a way to try again. It is
/// never "No TVs yet", which would be untrue.
class DevicesLoadFailed extends StatelessWidget {
  /// Creates the message; [onRetry] runs when Try again is tapped.
  const DevicesLoadFailed({required this.onRetry, super.key});

  /// Reloads the list.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.m,
          children: [
            Text(
              l10n.devicesLoadFailed,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            FilledButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
          ],
        ),
      ),
    );
  }
}
