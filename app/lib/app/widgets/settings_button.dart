import 'package:flutter/material.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';

/// The app-bar button that opens Settings: the same icon, label and size on
/// discovery, the remote with no TV and the remote.
///
/// It sets no colour of its own, so the app bar's theme (and reduce
/// motion's overlay, decision #47) apply unchanged.
class SettingsButton extends StatelessWidget {
  /// Creates the button; [onPressed] opens the Settings page that fits the
  /// caller.
  const SettingsButton({required this.onPressed, super.key});

  /// Opens Settings.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    icon: const Icon(Icons.settings_outlined),
    tooltip: AppLocalizations.of(context).pageTitleSettings,
    style: IconButton.styleFrom(
      minimumSize: const Size.square(AppSizes.touchMin),
    ),
    onPressed: onPressed,
  );
}
