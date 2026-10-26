import 'package:flutter/material.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/app/widgets/app_sheet.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/tv/saved_device_x.dart';

/// The TV name in the app bar. Tapping it opens a sheet to switch to another
/// saved TV or add one.
class DeviceSwitcher extends StatelessWidget {
  /// Creates a switcher showing [currentName].
  const DeviceSwitcher({
    required this.currentName,
    required this.currentServiceName,
    required this.devices,
    required this.onSelect,
    required this.onAddTv,
    required this.onManageTvs,
    super.key,
  });

  /// The name of the TV in use.
  final String currentName;

  /// The `serviceName` of the TV in use, which gets a check mark in the list;
  /// `null` when it isn't a saved TV (the demo TV).
  final String? currentServiceName;

  /// The saved TVs to choose from.
  final List<SavedDevice> devices;

  /// Called with the `serviceName` of the TV the user picked, after the sheet
  /// has closed.
  final ValueChanged<String> onSelect;

  /// Called after the sheet has closed, when the user chose "Add a TV".
  final VoidCallback onAddTv;

  /// Called after the sheet has closed, when the user chose "Manage TVs".
  final VoidCallback onManageTvs;

  Future<void> _open(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showAppSheet<_Choice>(
      context: context,
      title: l10n.remoteSwitchTv,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final device in devices)
            ListTile(
              minTileHeight: AppSizes.touchMin,
              title: Text(device.label),
              trailing: device.serviceName == currentServiceName
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(
                sheetContext,
              ).pop(_Select(device.serviceName)),
            ),
          ListTile(
            minTileHeight: AppSizes.touchMin,
            leading: const Icon(Icons.tune),
            title: Text(l10n.remoteManageTvs),
            onTap: () => Navigator.of(sheetContext).pop(const _ManageTvs()),
          ),
          ListTile(
            minTileHeight: AppSizes.touchMin,
            leading: const Icon(Icons.add),
            title: Text(l10n.remoteAddTv),
            onTap: () => Navigator.of(sheetContext).pop(const _AddTv()),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    switch (picked) {
      case _Select(:final serviceName):
        onSelect(serviceName);
      case _AddTv():
        onAddTv();
      case _ManageTvs():
        onManageTvs();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Tooltip(
        message: l10n.remoteSwitchTv,
        child: TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(AppSizes.touchMin, AppSizes.touchMin),
            foregroundColor: context.appColors.textPrimary,
            textStyle: Theme.of(context).textTheme.titleMedium,
          ),
          onPressed: () => _open(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  currentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.expand_more),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the user picked in the sheet.
sealed class _Choice {
  const _Choice();
}

final class _Select extends _Choice {
  const _Select(this.serviceName);

  final String serviceName;
}

final class _AddTv extends _Choice {
  const _AddTv();
}

final class _ManageTvs extends _Choice {
  const _ManageTvs();
}
