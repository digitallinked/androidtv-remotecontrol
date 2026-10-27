import 'package:flutter/material.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/widgets/placeholder_screen.dart';

/// Settings → Privacy choices. This is a placeholder until Task 6.6.
class PrivacyChoicesPage extends StatelessWidget {
  /// Creates the page.
  const PrivacyChoicesPage({super.key});

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
    title: AppLocalizations.of(context).pageTitlePrivacyChoices,
  );
}
