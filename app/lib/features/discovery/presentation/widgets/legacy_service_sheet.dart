import 'package:flutter/material.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/app/widgets/app_sheet.dart';

/// Explains that the TV called [tvName] runs an older remote service that
/// can't be controlled until it is updated.
///
/// Discovery keeps running underneath, so the TV shows up as updated on its
/// own; the button only closes the sheet.
Future<void> showLegacyServiceSheet(BuildContext context, String tvName) {
  final l10n = AppLocalizations.of(context);
  return showAppSheet<void>(
    context: context,
    title: l10n.legacyTitle,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.l,
      children: [
        Text(
          l10n.legacyBody(tvName),
          style: Theme.of(sheetContext).textTheme.bodyLarge,
        ),
        FilledButton(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: Text(l10n.discoverScanAgain),
        ),
      ],
    ),
  );
}
