import 'package:flutter/widgets.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/widgets/placeholder_screen.dart';

/// About this app: version, licences and credits.
///
/// A placeholder until its task builds the screen.
class AboutPage extends StatelessWidget {
  /// Creates the screen.
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
    title: AppLocalizations.of(context).pageTitleAbout,
  );
}
