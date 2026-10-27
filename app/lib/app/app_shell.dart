import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tv_remote/app/app_links.dart';
import 'package:tv_remote/app/flavor.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/core/config/update_gate.dart';
import 'package:tv_remote/core/links/link_opener.dart';
import 'package:tv_remote/features/demo/presentation/demo_badge.dart';

/// The `MaterialApp.router` builder: everything that sits around every
/// screen. That is the forced-update gate and the demo-mode strip.
Widget buildAppShell(BuildContext context, Widget? child) => UpdateGate(
  child: DemoBadgeOverlay(child: child ?? const SizedBox.shrink()),
);

/// Shows [child], or, while this app version is older than the configured
/// minimum, a blocking "Update required" screen in its place (Ruling P6-R7).
///
/// The screen replaces every route, the demo included. Its only action opens
/// the store listing.
class UpdateGate extends ConsumerWidget {
  /// Creates the gate around [child] (usually the app's navigator).
  const UpdateGate({required this.child, super.key});

  /// The app, shown while no update is required.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(updateRequiredProvider) ? const _UpdateRequiredScreen() : child;
}

class _UpdateRequiredScreen extends ConsumerWidget {
  const _UpdateRequiredScreen();

  Future<void> _openStore(BuildContext context, WidgetRef ref) async {
    final listing = AppLinks.storeListing(
      ref.read(flavorProvider),
      defaultTargetPlatform,
    );
    final opened = await ref.read(linkOpenerProvider).open(listing);
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).updateRequiredFailed),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Back must not reach a screen behind this one.
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: AppSpacing.l,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.updateRequiredTitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                    Text(
                      l10n.updateRequiredBody,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                    FilledButton(
                      onPressed: () => _openStore(context, ref),
                      child: Text(l10n.updateRequiredAction),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
