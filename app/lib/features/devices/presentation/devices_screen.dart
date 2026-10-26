import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/core/tv/saved_device_x.dart';

/// Your TVs: the TVs saved on this phone, most recently used first.
///
/// Tapping one opens Edit TV. A TV that was nicknamed shows the name it
/// announced under the nickname; the TV the remote is using is marked "In
/// use", and one without a trusted key "Needs pairing".
class DevicesScreen extends ConsumerWidget {
  /// Creates the screen.
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final saved = ref.watch(savedDevicesProvider);
    final inUse = ref
        .watch(remoteSessionProvider)
        .value
        ?.pairingTarget
        ?.serviceName;
    final devices = saved.value;

    final Widget body;
    if (devices == null && saved.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (devices == null || devices.isEmpty) {
      // A failed read looks like an empty list: the way out is the same.
      body = _Empty(onAdd: () => unawaited(context.push(AppRoutes.discover)));
    } else {
      body = ListView.separated(
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: AppSpacing.s,
        ),
        itemCount: devices.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final device = devices[index];
          return _DeviceTile(
            device: device,
            inUse: device.serviceName == inUse,
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pageTitleDevices),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.remoteAddTv,
            style: IconButton.styleFrom(
              minimumSize: const Size.square(AppSizes.touchMin),
            ),
            onPressed: () => unawaited(context.push(AppRoutes.discover)),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SafeArea(child: body),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device, required this.inUse});

  final SavedDevice device;
  final bool inUse;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = device.label;
    final details = [
      // The TV's own name, so a nickname never hides which TV it is.
      if (device.nickname != null) device.displayName,
      if (inUse) l10n.devicesInUse,
      if (device.serverKeyPin == null) l10n.statusNeedsPairing,
    ];
    return ListTile(
      minTileHeight: AppSizes.touchMin + AppSpacing.s,
      leading: const Icon(Icons.tv),
      title: Text(label),
      subtitle: details.isEmpty ? null : Text(details.join(' · ')),
      trailing: Icon(
        Icons.chevron_right,
        semanticLabel: l10n.devicesEditTv(label),
      ),
      onTap: () => unawaited(
        context.push(AppRoutes.editDevice(device.serviceName)),
      ),
    );
  }
}

/// No TV is saved: say so and offer to add one.
class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.m,
          children: [
            Text(
              l10n.devicesEmptyTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            Text(
              l10n.devicesEmptyBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: context.appColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            FilledButton(onPressed: onAdd, child: Text(l10n.remoteAddTv)),
          ],
        ),
      ),
    );
  }
}
