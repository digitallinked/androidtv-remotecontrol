import 'package:flutter/material.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/widgets/app_dialog.dart';

/// Explains the iOS Local Network prompt before discovery triggers it
/// (Ruling P7-R3).
///
/// A themed dialog with one action, "Continue". Neither the barrier nor
/// Back closes it, the same pattern as the tracking pre-prompt. Completes
/// when "Continue" is tapped.
Future<void> showLocalNetworkExplainer(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showAppDialog<void>(
    context: context,
    title: l10n.onboardingLocalNetworkTitle,
    message: l10n.onboardingLocalNetworkBody,
    actions: [
      AppDialogAction(
        label: l10n.onboardingContinue,
        value: null,
        isPrimary: true,
      ),
    ],
    barrierDismissible: false,
  );
}
