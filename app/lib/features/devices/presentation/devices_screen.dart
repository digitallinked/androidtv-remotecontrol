import 'package:flutter/widgets.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/widgets/placeholder_screen.dart';

/// Your TVs: the TVs saved on this phone.
///
/// A placeholder until its task builds the screen.
class DevicesScreen extends StatelessWidget {
  /// Creates the screen.
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
    title: AppLocalizations.of(context).pageTitleDevices,
  );
}
