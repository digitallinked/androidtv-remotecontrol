import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/app/widgets/app_snack_bar.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/core/tv/manual_tv.dart';
import 'package:tv_remote/features/discovery/application/discovery_controller.dart';
import 'package:tv_remote/features/discovery/presentation/manual_ip_sheet.dart';
import 'package:tv_remote/features/discovery/presentation/widgets/discovery_empty_state.dart';
import 'package:tv_remote/features/discovery/presentation/widgets/legacy_service_sheet.dart';
import 'package:tv_remote/features/discovery/presentation/widgets/troubleshooting_sheet.dart';
import 'package:tv_remote/features/discovery/presentation/widgets/tv_list_tile.dart';

/// Lists the TVs on the network, with ways in when none shows up: scan again,
/// troubleshooting, an IP address, or the demo TV.
class DiscoveryScreen extends ConsumerStatefulWidget {
  /// Creates the discovery screen.
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  /// A tap on a paired TV is being handled; further taps wait for it.
  bool _opening = false;

  @override
  Widget build(BuildContext context) {
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
    final savedNames = {
      if (saved != null)
        for (final device in saved) device.serviceName,
    };
    // A TV added by IP address that mDNS now shows under its own name: same
    // address, a pinned key, and no row under the mDNS name yet (Ruling
    // P5-R10 d). Tapping it moves the saved entry (and its pin) over.
    final manualMatches = <String, SavedDevice>{
      if (saved != null)
        for (final tv in state.tvs)
          if (!tv.isLegacyService && !savedNames.contains(tv.serviceName))
            for (final device in saved)
              if (isManualServiceName(device.serviceName) &&
                  device.serverKeyPin != null &&
                  device.lastHost == tv.host)
                tv.serviceName: device,
    };

    final Widget body;
    if (state.tvs.isNotEmpty) {
      body = ListView.builder(
        itemCount: state.tvs.length,
        itemBuilder: (context, index) {
          final tv = state.tvs[index];
          return TvListTile(
            tv: tv,
            isPaired:
                pairedNames.contains(tv.serviceName) ||
                manualMatches.containsKey(tv.serviceName),
            onTap: () => unawaited(_open(tv, pairedNames, manualMatches)),
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
      appBar: AppBar(
        title: Text(l10n.discoverTitle),
        actions: [
          // Settings before pairing (Ruling P7-R7): help, privacy and
          // feedback without a TV, and no interstitial on the way back.
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.pageTitleSettings,
            onPressed: () =>
                unawaited(context.push(AppRoutes.settingsFromSetup)),
          ),
        ],
      ),
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
                    onPressed: () => unawaited(_enterIp()),
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

  Future<void> _open(
    DiscoveredTv tv,
    Set<String> pairedNames,
    Map<String, SavedDevice> manualMatches,
  ) async {
    if (_opening) return;
    if (tv.isLegacyService) {
      unawaited(
        showLegacyServiceSheet(
          context,
          tv.displayName,
          onScanAgain: ref.read(discoveryControllerProvider.notifier).rescan,
        ),
      );
      return;
    }
    final paired = pairedNames.contains(tv.serviceName);
    final manual = manualMatches[tv.serviceName];
    if (!paired && manual == null) {
      unawaited(context.push(AppRoutes.pair(tv.serviceName), extra: tv));
      return;
    }

    // Read before the first await: the screen may go away meanwhile.
    final devices = ref.read(deviceRepositoryProvider);
    final target = ref.read(activeTargetProvider.notifier);
    final discovery = ref.read(discoveryControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final failed = AppLocalizations.of(context).discoverOpenFailed;
    _opening = true;
    try {
      if (paired) {
        // Remember where the TV is now, so the connection doesn't start from
        // an old address. Failing to save is not a reason to stay out.
        try {
          await devices.setLastHost(tv.serviceName, tv.host);
        } on Object {
          // Connecting with the old address still works if it hasn't moved.
        }
        // Nobody who went elsewhere meanwhile is pulled back to this TV.
        if (mounted) target.activateDevice(tv.serviceName);
      } else {
        // The saved pin moves with the row, so a different TV at this address
        // still fails the key check on connect. The remote must not keep
        // following the row the merge removes: the controller moves it to
        // the merged TV even when the user has left (Ruling P8-R10), but
        // pulls nobody who went elsewhere onto this TV.
        final bool adopted;
        try {
          adopted = await discovery.adoptManualDevice(
            manualServiceName: manual!.serviceName,
            tv: tv,
            opening: () => mounted,
          );
        } on Object {
          messenger.showAppSnackBar(SnackBar(content: Text(failed)));
          return;
        }
        if (!adopted) {
          messenger.showAppSnackBar(SnackBar(content: Text(failed)));
          return;
        }
      }
      // The user may have left meanwhile: nobody who went elsewhere is
      // pulled back to the remote.
      if (mounted) router.go(AppRoutes.remote);
    } finally {
      _opening = false;
    }
  }

  Future<void> _enterIp() async {
    final tv = await showManualIpSheet(context);
    if (tv == null || !mounted) return;
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
            CircularProgressIndicator(
              semanticsLabel: AppLocalizations.of(context).loadingLabel,
            ),
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
