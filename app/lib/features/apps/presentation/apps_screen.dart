import 'package:flutter/widgets.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/widgets/placeholder_screen.dart';

/// The Apps screen: search and open the apps on the TV.
///
/// A placeholder until its task builds the screen.
class AppsScreen extends StatelessWidget {
  /// Creates the screen.
  const AppsScreen({super.key});

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
    title: AppLocalizations.of(context).pageTitleApps,
  );
}
