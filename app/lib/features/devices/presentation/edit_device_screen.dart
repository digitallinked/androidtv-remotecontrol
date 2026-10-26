import 'package:flutter/widgets.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/widgets/placeholder_screen.dart';

/// Edit TV: rename, set the MAC address or remove a saved TV.
///
/// A placeholder until its task builds the screen.
class EditDeviceScreen extends StatelessWidget {
  /// Creates the screen for the saved TV [serviceName].
  const EditDeviceScreen({required this.serviceName, super.key});

  /// Service name of the saved TV being edited (decoded).
  final String serviceName;

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
    title: AppLocalizations.of(context).pageTitleEditDevice,
    params: {'serviceName': serviceName},
  );
}
