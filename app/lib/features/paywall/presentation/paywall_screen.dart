import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tv_remote/app/app_links.dart';
import 'package:tv_remote/app/flavor.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/core/purchases/purchase_service.dart';
import 'package:tv_remote/features/paywall/application/paywall_controller.dart';
import 'package:tv_remote/features/paywall/domain/paywall_source.dart';
import 'package:tv_remote/features/paywall/presentation/widgets/plan_tile.dart';
import 'package:tv_remote/features/settings/application/feedback.dart';

/// The Premium screen (Ruling P6-R11): what Premium gives, the plans with
/// their prices and renewal terms, Continue, Restore, the store's billing
/// terms and the legal links, all in one scroll view.
///
/// It closes with the ✕ and returns to where it was opened from. There is no
/// banner here, ever.
class PaywallScreen extends ConsumerWidget {
  /// Creates the screen, opened from [source].
  const PaywallScreen({required this.source, super.key});

  /// Where the screen was opened from.
  final PaywallSource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(paywallControllerProvider(source));
    final bottom = MediaQuery.paddingOf(context).bottom;
    final children = switch (state) {
      PaywallLoading() => [const _Loading()],
      PaywallUnavailable() => [_Unavailable(source: source)],
      PaywallReady() => [
        _Plans(
          source: source,
          state: state,
          // From this screen's own context: the plans below may be gone by
          // the time a purchase ends, this screen is not.
          onClose: () {
            if (context.mounted) _close(context);
          },
        ),
      ],
      PaywallActive() => [_Active(source: source, state: state)],
    };
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.closeAction,
          onPressed: () => _close(context),
        ),
        title: Text(l10n.pageTitlePaywall),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: EdgeInsetsDirectional.fromSTEB(
              AppSpacing.l,
              AppSpacing.s,
              AppSpacing.l,
              bottom + AppSpacing.xl,
            ),
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Goes back to where the paywall was opened from, or to the remote when
/// there is nothing to go back to.
void _close(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(AppRoutes.remote);
  }
}

void _say(ScaffoldMessengerState messenger, String message) => messenger
  ..clearSnackBars()
  ..showSnackBar(SnackBar(content: Text(message)));

/// Restores earlier purchases and says how it went.
Future<void> _restore(
  BuildContext context,
  WidgetRef ref,
  PaywallSource source,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final outcome = await ref
      .read(paywallControllerProvider(source).notifier)
      .restore();
  // Nothing to say when the restore never ran (the screen was busy).
  if (outcome == null) return;
  _say(
    messenger,
    switch (outcome) {
      RestoreOutcome.restoredPremium => l10n.paywallRestored,
      RestoreOutcome.nothingToRestore => l10n.paywallNothingToRestore,
      RestoreOutcome.failed => l10n.paywallRestoreFailed,
    },
  );
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.l),
          Text(
            l10n.paywallLoading,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Unavailable extends ConsumerWidget {
  const _Unavailable({required this.source});

  final PaywallSource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.l),
        Semantics(
          header: true,
          child: Text(
            l10n.paywallUnavailableTitle,
            style: theme.textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        Text(
          l10n.paywallUnavailableBody,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: () =>
              ref.read(paywallControllerProvider(source).notifier).retry(),
          child: Text(l10n.commonRetry),
        ),
      ],
    );
  }
}

class _Active extends ConsumerWidget {
  const _Active({required this.source, required this.state});

  final PaywallSource source;
  final PaywallActive state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lifetime = state.premium.lifetime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.l),
        Semantics(
          header: true,
          child: Text(
            l10n.paywallActiveTitle,
            style: theme.textTheme.displaySmall,
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        Text(
          lifetime ? l10n.paywallActiveLifetime : l10n.paywallActiveBody,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (!lifetime) ...[
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.square(AppSizes.touchMin),
            ),
            onPressed: () => unawaited(
              openExternal(
                context,
                ref,
                AppLinks.manageSubscriptions(
                  ref.read(flavorProvider),
                  defaultTargetPlatform,
                ),
              ),
            ),
            child: Text(l10n.paywallManageSubscription),
          ),
          const SizedBox(height: AppSpacing.s),
        ],
        TextButton(
          onPressed: state.busy
              ? null
              : () => unawaited(_restore(context, ref, source)),
          child: Text(l10n.paywallRestore),
        ),
        if (state.busy) _Busy(state.busyWith!),
      ],
    );
  }
}

/// The purchase or restore in progress ("Confirming your purchase…" or
/// "Restoring your purchases…") with a spinner, announced to screen readers.
class _Busy extends StatelessWidget {
  const _Busy(this.busyWith);

  final PaywallBusy busyWith;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.m),
      child: Semantics(
        liveRegion: true,
        child: Row(
          children: [
            const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Text(
                switch (busyWith) {
                  PaywallBusy.purchasing => l10n.paywallPurchasing,
                  PaywallBusy.restoring => l10n.paywallRestoring,
                },
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Plans extends ConsumerWidget {
  const _Plans({
    required this.source,
    required this.state,
    required this.onClose,
  });

  final PaywallSource source;
  final PaywallReady state;

  /// Closes the paywall; a no-op once the paywall itself is gone.
  final VoidCallback onClose;

  String _title(AppLocalizations l10n, PremiumPlanKind kind) => switch (kind) {
    PremiumPlanKind.monthly => l10n.paywallPlanMonthly,
    PremiumPlanKind.yearly => l10n.paywallPlanYearly,
    PremiumPlanKind.lifetime => l10n.paywallPlanLifetime,
  };

  String _price(AppLocalizations l10n, PremiumPlan plan) => switch (plan.kind) {
    PremiumPlanKind.monthly => l10n.paywallPricePerMonth(plan.priceString),
    PremiumPlanKind.yearly => l10n.paywallPricePerYear(plan.priceString),
    PremiumPlanKind.lifetime => l10n.paywallPriceOnce(plan.priceString),
  };

  String _terms(AppLocalizations l10n, PremiumPlanKind kind) => switch (kind) {
    PremiumPlanKind.monthly => l10n.paywallRenewsMonthly,
    PremiumPlanKind.yearly => l10n.paywallRenewsYearly,
    PremiumPlanKind.lifetime => l10n.paywallLifetimeTerms,
  };

  Future<void> _purchase(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await ref
        .read(paywallControllerProvider(source).notifier)
        .purchase();
    switch (outcome) {
      case Purchased():
        _say(messenger, l10n.paywallWelcome);
        onClose();
      case PurchaseCancelled():
        break;
      case PurchasePending():
        _say(messenger, l10n.paywallPending);
      case PurchaseFailed(:final failure):
        _say(
          messenger,
          switch (failure) {
            PurchaseFailure.network => l10n.paywallNetworkError,
            PurchaseFailure.notAllowed => l10n.paywallNotAllowed,
            PurchaseFailure.alreadyOwned => l10n.paywallAlreadyOwned,
            PurchaseFailure.storeProblem ||
            PurchaseFailure.unknown => l10n.paywallFailed,
          },
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.appColors;
    final controller = ref.read(paywallControllerProvider(source).notifier);
    final secondary = theme.textTheme.bodyLarge?.copyWith(
      color: colors.textSecondary,
    );
    final terms = defaultTargetPlatform == TargetPlatform.iOS
        ? l10n.paywallTermsIos
        : l10n.paywallTermsAndroid;

    Widget benefit(IconData icon, String title, String body) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: colors.accent),
      title: Text(title, style: theme.textTheme.labelLarge),
      subtitle: Text(body, style: secondary),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.s),
        Semantics(
          header: true,
          child: Text(
            l10n.paywallHeadline,
            style: theme.textTheme.displaySmall,
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        Text(l10n.paywallSubhead, style: secondary),
        const SizedBox(height: AppSpacing.m),
        benefit(
          Icons.block,
          l10n.paywallBenefitNoAds,
          l10n.paywallBenefitNoAdsBody,
        ),
        benefit(
          Icons.palette_outlined,
          l10n.paywallBenefitStyles,
          l10n.paywallBenefitStylesBody,
        ),
        const SizedBox(height: AppSpacing.s),
        Text(l10n.paywallFreeForever, style: secondary),
        Padding(
          padding: const EdgeInsetsDirectional.only(
            top: AppSpacing.m,
            bottom: AppSpacing.s,
          ),
          child: Semantics(
            header: true,
            child: Text(
              l10n.paywallChoosePlan,
              style: theme.textTheme.titleLarge,
            ),
          ),
        ),
        RadioGroup<PremiumPlanKind>(
          groupValue: state.selected,
          onChanged: (kind) {
            if (kind != null) controller.select(kind);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final plan in state.offer.plans) ...[
                PlanTile(
                  kind: plan.kind,
                  title: _title(l10n, plan.kind),
                  price: _price(l10n, plan),
                  terms: _terms(l10n, plan.kind),
                  selected: state.selected == plan.kind,
                  enabled: !state.busy,
                  onTap: () => controller.select(plan.kind),
                  badges: [
                    if (plan.kind == PremiumPlanKind.yearly &&
                        state.badgePercent != null) ...[
                      l10n.paywallBestValue,
                      l10n.paywallSavePercent(state.badgePercent!),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.s),
              ],
            ],
          ),
        ),
        if (state.busy) _Busy(state.busyWith!),
        const SizedBox(height: AppSpacing.m),
        FilledButton(
          onPressed: state.busy || state.selected == null
              ? null
              : () => unawaited(_purchase(context, ref)),
          child: Text(l10n.paywallContinue),
        ),
        const SizedBox(height: AppSpacing.s),
        TextButton(
          onPressed: state.busy
              ? null
              : () => unawaited(_restore(context, ref, source)),
          child: Text(l10n.paywallRestore),
        ),
        const SizedBox(height: AppSpacing.s),
        Text(
          terms,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        Wrap(
          spacing: AppSpacing.s,
          children: [
            TextButton(
              onPressed: () =>
                  unawaited(openExternal(context, ref, AppLinks.terms)),
              child: Text(l10n.settingsTerms),
            ),
            TextButton(
              onPressed: () =>
                  unawaited(openExternal(context, ref, AppLinks.privacyPolicy)),
              child: Text(l10n.settingsPrivacy),
            ),
          ],
        ),
      ],
    );
  }
}
