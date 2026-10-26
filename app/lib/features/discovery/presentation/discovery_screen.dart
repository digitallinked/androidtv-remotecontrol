import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/discovery/application/discovery_controller.dart';
import 'package:tv_remote/features/discovery/presentation/manual_ip_sheet.dart';
import 'package:tv_remote/features/discovery/presentation/widgets/discovery_empty_state.dart';
import 'package:tv_remote/features/discovery/presentation/widgets/legacy_service_sheet.dart';
import 'package:tv_remote/features/discovery/presentation/widgets/troubleshooting_sheet.dart';
import 'package:tv_remote/features/discovery/presentation/widgets/tv_list_tile.dart';

/// Lists the TVs on the network, with ways in when none shows up: scan again,
/// troubleshooting, an IP address, or the demo TV.
class DiscoveryScreen extends ConsumerWidget {
  /// Creates the discovery screen.
  const DiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(discoveryControllerProvider);
    final controller = ref.read(discoveryControllerProvider.notifier);
    // A loading or failed list of saved TVs counts as "none paired".
    final saved = ref.watch(savedDevicesProvider).value;
    final pairedNames = <String>{
      if (saved != null)
        for (final device in saved)
          if (device.serverKeyPin != null) device.serviceName,
    };

    final Widget body;
    if (state.tvs.isNotEmpty) {
      body = ListView.builder(
        itemCount: state.tvs.length,
        itemBuilder: (context, index) {
          final tv = state.tvs[index];
          return TvListTile(
            tv: tv,
            isPaired: pairedNames.contains(tv.serviceName),
            onTap: () => _open(context, ref, tv, pairedNames),
          );
        },
      );
    } else if (state.showTroubleshooting) {
      body = DiscoveryEmptyState(
        failed: state.failed,
        onScanAgain: controller.rescan,
        onTroubleshooting: () => unawaited(showTroubleshootingSheet(context)),
      );
    } else {
      body = _Searching(label: l10n.discoverSearching);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.discoverTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: body),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.l,
                vertical: AppSpacing.s,
              ),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.s,
                children: [
                  TextButton(
                    onPressed: () => unawaited(_enterIp(context)),
                    child: Text(l10n.discoverEnterIp),
                  ),
                  TextButton(
                    onPressed: () {
                      ref.read(activeTargetProvider.notifier).startDemo();
                      context.go(AppRoutes.remote);
                    },
                    child: Text(l10n.discoverTryDemo),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _open(
    BuildContext context,
    WidgetRef ref,
    DiscoveredTv tv,
    Set<String> pairedNames,
  ) {
    if (tv.isLegacyService) {
      unawaited(showLegacyServiceSheet(context, tv.displayName));
    } else if (pairedNames.contains(tv.serviceName)) {
      ref.read(activeTargetProvider.notifier).activateDevice(tv.serviceName);
      context.go(AppRoutes.remote);
    } else {
      unawaited(context.push(AppRoutes.pair(tv.serviceName), extra: tv));
    }
  }

  Future<void> _enterIp(BuildContext context) async {
    final tv = await showManualIpSheet(context);
    if (tv == null || !context.mounted) return;
    unawaited(context.push(AppRoutes.pair(tv.serviceName), extra: tv));
  }
}

/// The spinner shown while the first search is running.
class _Searching extends StatelessWidget {
  const _Searching({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.l,
          children: [
            const CircularProgressIndicator(),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: context.appColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
