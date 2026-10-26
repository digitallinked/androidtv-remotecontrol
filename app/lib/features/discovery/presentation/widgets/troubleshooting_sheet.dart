import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/app/widgets/app_sheet.dart';

/// Shows the numbered steps to try when no TV is found.
///
/// The Local Network step appears on iPhone only.
Future<void> showTroubleshootingSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final steps = [
    l10n.troubleshootSameWifi,
    l10n.troubleshootTvOn,
    l10n.troubleshootRemoteService,
    if (defaultTargetPlatform == TargetPlatform.iOS)
      l10n.troubleshootLocalNetwork,
    l10n.troubleshootRestart,
    l10n.troubleshootManualIp,
  ];
  return showAppSheet<void>(
    context: context,
    title: l10n.troubleshootTitle,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.m,
      children: [
        for (final (index, step) in steps.indexed)
          _Step(number: index + 1, text: step),
      ],
    ),
  );
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The number column grows with the text size, so "6." never wraps.
        SizedBox(
          width: MediaQuery.textScalerOf(context).scale(28),
          child: Text(
            '$number.',
            style: style?.copyWith(
              color: context.appColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: Text(text, style: style)),
      ],
    );
  }
}
