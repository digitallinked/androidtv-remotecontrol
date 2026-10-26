import 'package:flutter/widgets.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/widgets/placeholder_screen.dart';

/// Help: troubleshooting and common questions.
///
/// A placeholder until its task builds the screen.
class HelpPage extends StatelessWidget {
  /// Creates the screen.
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
    title: AppLocalizations.of(context).pageTitleHelp,
  );
}
