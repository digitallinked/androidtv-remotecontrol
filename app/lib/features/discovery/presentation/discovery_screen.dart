import 'package:flutter/material.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/features/discovery/presentation/widgets/discovery_empty_state.dart';

/// Lists the TVs on the network. For now it only shows the empty state;
/// scanning, manual entry and demo mode arrive in Phase 3.
class DiscoveryScreen extends StatelessWidget {
  /// Creates the discovery screen.
  const DiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.discoverTitle)),
      body: const SafeArea(child: DiscoveryEmptyState()),
    );
  }
}
