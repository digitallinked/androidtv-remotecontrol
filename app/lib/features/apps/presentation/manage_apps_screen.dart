import 'package:flutter/widgets.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/widgets/placeholder_screen.dart';

/// Edit apps: add, reorder, edit and remove app shortcuts.
///
/// A placeholder until its task builds the screen.
class ManageAppsScreen extends StatelessWidget {
  /// Creates the screen.
  const ManageAppsScreen({super.key});

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
    title: AppLocalizations.of(context).pageTitleManageApps,
  );
}
