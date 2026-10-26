import 'package:flutter/widgets.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/widgets/placeholder_screen.dart';

/// Settings page for the remote behaviour.
///
/// A placeholder until its task builds the screen.
class RemoteBehaviourPage extends StatelessWidget {
  /// Creates the screen.
  const RemoteBehaviourPage({super.key});

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
    title: AppLocalizations.of(context).pageTitleRemoteBehaviour,
  );
}
