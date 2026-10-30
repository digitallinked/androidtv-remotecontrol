import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tv_remote/app/app_links.dart';
import 'package:tv_remote/app/flavor.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/app_theme.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/app/widgets/app_snack_bar.dart';
import 'package:tv_remote/core/config/update_gate.dart';
import 'package:tv_remote/core/links/link_opener.dart';
import 'package:tv_remote/features/demo/presentation/demo_badge.dart';

/// The `MaterialApp.router` builder: everything that sits around every
/// screen. That is the reduce-motion theme, the forced-update gate and the
/// demo-mode strip.
Widget buildAppShell(BuildContext context, Widget? child) => ReduceMotionTheme(
  child: UpdateGate(
    child: DemoBadgeOverlay(child: child ?? const SizedBox.shrink()),
  ),
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

class _UpdateRequiredScreen extends ConsumerStatefulWidget {
  const _UpdateRequiredScreen();

  @override
  ConsumerState<_UpdateRequiredScreen> createState() =>
      _UpdateRequiredScreenState();
}

class _UpdateRequiredScreenState extends ConsumerState<_UpdateRequiredScreen> {
  /// A store page is being opened; a second tap meanwhile does nothing.
  bool _opening = false;

  Future<void> _openStore() async {
    if (_opening) return;
    _opening = true;
    try {
      await _launchStore();
    } finally {
      _opening = false;
    }
  }

  Future<void> _launchStore() async {
    final listing = AppLinks.storeListing(
      ref.read(flavorProvider),
      defaultTargetPlatform,
    );
    final opened = await ref.read(linkOpenerProvider).open(listing);
    if (opened || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showAppSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).updateRequiredFailed),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // This gate sits above the Navigator, so the router is out of the tree
    // while it shows: system Back finds no route to pop and leaves the app,
    // and a relaunch is gated again. Nothing behind this screen can be
    // reached. The PopScope is a harmless guard, not the mechanism.
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
                      onPressed: _openStore,
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
