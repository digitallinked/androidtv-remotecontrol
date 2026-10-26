import 'package:flutter/material.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/app/widgets/app_sheet.dart';

/// Opens a sheet that explains where to find the TV's Wi-Fi or Ethernet MAC
/// address, and that it isn't the Bluetooth one.
Future<void> showWolMacHelpSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showAppSheet<void>(
    context: context,
    title: l10n.wolHelpTitle,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.m,
        children: [
          Text(l10n.wolSetupBody, style: theme.textTheme.bodyLarge),
          Text(
            l10n.wolNotBluetooth,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            l10n.wolMayNotWork,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: sheetContext.appColors.textSecondary,
            ),
          ),
        ],
      );
    },
  );
}
