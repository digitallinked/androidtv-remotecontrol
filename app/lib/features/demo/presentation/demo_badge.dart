import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/app/widgets/app_dialog.dart';
import 'package:tv_remote/features/demo/demo_providers.dart';

/// Shows a "Demo mode" strip above [child] while the demo TV is active.
///
/// The strip is a row of its own, not an overlay: the screen below starts
/// under it, so no control is ever covered. Outside demo mode [child] fills
/// the space and the strip is gone.
class DemoBadgeOverlay extends ConsumerWidget {
  /// Creates the overlay around [child] (usually the app's navigator).
  const DemoBadgeOverlay({required this.child, super.key});

  /// The app below the strip.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDemo = ref.watch(isDemoActiveProvider);
    // The same widgets in the same places whether or not the strip shows, so
    // the navigator below keeps its state when demo mode starts or ends.
    return Column(
      children: [
        if (isDemo) const _DemoStrip() else const SizedBox.shrink(),
        Expanded(
          // A page route's modal barrier blocks the semantics of everything
          // painted before it under the same semantics parent, which would
          // hide the strip from screen readers. Its own node keeps the
          // barrier's effect inside the app.
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            // The strip already covers the status bar.
            child: MediaQuery.removePadding(
              context: context,
              removeTop: isDemo,
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}

class _DemoStrip extends ConsumerStatefulWidget {
  const _DemoStrip();

  @override
  ConsumerState<_DemoStrip> createState() => _DemoStripState();
}

class _DemoStripState extends ConsumerState<_DemoStrip> {
  /// The dialog is open. The strip sits outside the navigator, so its
  /// barrier doesn't cover the button.
  bool _asking = false;

  Future<void> _askToLeave() async {
    if (_asking) return;
    // The strip is built above the navigator, so the dialog needs the
    // navigator's own context.
    final navigatorContext = ref
        .read(appRouterProvider)
        .routerDelegate
        .navigatorKey
        .currentContext;
    if (navigatorContext == null) return;
    final l10n = AppLocalizations.of(context);
    _asking = true;
    final leave = await showAppDialog<bool>(
      context: navigatorContext,
      title: l10n.demoLeaveTitle,
      message: l10n.demoLeaveMessage,
      actions: [
        AppDialogAction(label: l10n.demoStay, value: false),
        AppDialogAction(
          label: l10n.demoLeaveConfirm,
          value: true,
          isPrimary: true,
        ),
      ],
    );
    _asking = false;
    if ((leave ?? false) && mounted) unawaited(leaveDemo(ref));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return Semantics(
      container: true,
      label: l10n.demoBadgeLabel,
      child: Material(
        color: colors.surfaceRaised,
        child: SafeArea(
          bottom: false,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.touchMin),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: AppSpacing.l,
                end: AppSpacing.s,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ExcludeSemantics(
                      child: Text(
                        l10n.demoBadgeLabel,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _askToLeave,
                    child: Text(l10n.demoLeaveAction),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
