import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/analytics/analytics_events.dart';
import 'package:tv_remote/core/analytics/app_analytics.dart';
import 'package:tv_remote/core/config/app_config.dart';
import 'package:tv_remote/core/purchases/premium.dart';
import 'package:tv_remote/core/purchases/purchase_service.dart';
import 'package:tv_remote/features/paywall/domain/paywall_source.dart';

part 'paywall_controller.g.dart';

/// What the paywall shows.
@immutable
sealed class PaywallState {
  const PaywallState();
}

/// The plans are being loaded.
final class PaywallLoading extends PaywallState {
  /// Creates the state.
  const PaywallLoading();
}

/// The store has no plans to show, or can't be reached.
final class PaywallUnavailable extends PaywallState {
  /// Creates the state.
  const PaywallUnavailable();
}

/// The plans are on screen.
final class PaywallReady extends PaywallState {
  /// Creates the state.
  const PaywallReady({
    required this.offer,
    required this.selected,
    required this.busy,
    this.badgePercent,
  });

  /// The plans the store offers.
  final PremiumOffer offer;

  /// The plan Continue buys, or `null` when none is chosen yet (Lifetime is
  /// never pre-selected).
  final PremiumPlanKind? selected;

  /// Whether a purchase or a restore is running.
  final bool busy;

  /// The honest saving of the yearly plan to show as a badge, or `null`.
  final int? badgePercent;

  /// A copy with [selected] or [busy] changed.
  PaywallReady copyWith({
    PremiumPlanKind? selected,
    bool? busy,
  }) => PaywallReady(
    offer: offer,
    selected: selected ?? this.selected,
    busy: busy ?? this.busy,
    badgePercent: badgePercent,
  );
}

/// The user already has Premium.
final class PaywallActive extends PaywallState {
  /// Creates the state.
  const PaywallActive(this.premium, {this.busy = false});

  /// The Premium state being shown.
  final PremiumState premium;

  /// Whether a restore is running.
  final bool busy;
}

/// The plan to pre-select and the badge to show for [offer] (Ruling P6-R11).
///
/// Yearly, with a badge, when it costs less than twelve months; otherwise
/// monthly, or yearly when there is no monthly plan to compare it with, and
/// no badge. Lifetime is never chosen for the user.
@visibleForTesting
({PremiumPlanKind? selected, int? badge}) preselect(PremiumOffer offer) {
  final monthly = offer.plan(PremiumPlanKind.monthly);
  final yearly = offer.plan(PremiumPlanKind.yearly);
  if (monthly != null && yearly != null) {
    final percent = savePercent(monthly: monthly.price, yearly: yearly.price);
    if (percent != null) {
      return (selected: PremiumPlanKind.yearly, badge: percent);
    }
  }
  if (monthly != null) return (selected: PremiumPlanKind.monthly, badge: null);
  if (yearly != null) return (selected: PremiumPlanKind.yearly, badge: null);
  return (selected: null, badge: null);
}

/// The logic of the paywall opened from [source] (Ruling P6-R11).
///
/// Purchases and restores keep going when the screen is left: the answer is
/// still handed to [Premium] and counted.
@riverpod
class PaywallController extends _$PaywallController {
  bool _busy = false;

  @override
  PaywallState build(PaywallSource source) {
    final service = ref.watch(purchaseServiceProvider);
    final variant = ref.read(appConfigProvider).paywallVariant;
    ref.listen<PremiumState>(premiumProvider, (previous, next) {
      if (next.isPremium) {
        state = PaywallActive(next, busy: _busy);
      } else if (state is PaywallActive) {
        _reload(service);
      }
    });
    ref
        .read(appAnalyticsProvider.notifier)
        .log(AnalyticsEvent.paywallView(source: source, variant: variant));

    final premium = ref.read(premiumProvider);
    if (premium.isPremium) return PaywallActive(premium);
    // After build, so the state exists before it is set.
    scheduleMicrotask(() {
      if (ref.mounted) unawaited(_load(service));
    });
    return const PaywallLoading();
  }

  void _reload(PurchaseService service) {
    state = const PaywallLoading();
    unawaited(_load(service));
  }

  Future<void> _load(PurchaseService service) async {
    PremiumOffer? offer;
    try {
      offer = await service.loadOffer();
    } on Object catch (error) {
      developer.log('loading plans failed', name: 'paywall', error: error);
    }
    if (!ref.mounted || state is PaywallActive) return;
    if (offer == null || offer.plans.isEmpty) {
      state = const PaywallUnavailable();
      return;
    }
    final choice = preselect(offer);
    state = PaywallReady(
      offer: offer,
      selected: choice.selected,
      busy: false,
      badgePercent: choice.badge,
    );
  }

  /// Chooses the plan Continue buys. Ignored while busy or when the store
  /// doesn't offer [kind].
  void select(PremiumPlanKind kind) {
    final current = state;
    if (current is! PaywallReady || current.busy) return;
    if (current.offer.plan(kind) == null) return;
    state = current.copyWith(selected: kind);
  }

  /// Asks for the plans again after [PaywallUnavailable].
  void retry() {
    if (state is! PaywallUnavailable) return;
    _reload(ref.read(purchaseServiceProvider));
  }

  void _setBusy({required bool busy}) {
    _busy = busy;
    if (!ref.mounted) return;
    final current = state;
    state = switch (current) {
      PaywallReady() => current.copyWith(busy: busy),
      PaywallActive() => PaywallActive(current.premium, busy: busy),
      _ => current,
    };
  }

  /// Buys the selected plan. While the store is open the screen is busy.
  ///
  /// A call while busy, or with no plan selected, does nothing and answers
  /// [PurchaseCancelled].
  Future<PurchaseOutcome> purchase() async {
    final current = state;
    final kind = current is PaywallReady ? current.selected : null;
    if (_busy || kind == null) return const PurchaseCancelled();

    // Everything the end of the purchase needs is taken now: the screen may
    // be closed while the store sheet is open.
    final service = ref.read(purchaseServiceProvider);
    final premium = ref.read(premiumProvider.notifier);
    final analytics = ref.read(appAnalyticsProvider.notifier);
    _setBusy(busy: true);
    PurchaseOutcome outcome;
    try {
      outcome = await service.purchase(kind);
    } on Object catch (error) {
      developer.log('purchase failed', name: 'paywall', error: error);
      outcome = const PurchaseFailed(PurchaseFailure.unknown);
    }
    if (outcome case Purchased(:final entitlement)) {
      await premium.apply(entitlement);
      analytics.log(AnalyticsEvent.purchaseSuccess(kind.productId));
    }
    _setBusy(busy: false);
    return outcome;
  }

  /// Asks the store for earlier purchases. While it does, the screen is busy.
  Future<RestoreOutcome> restore() async {
    if (_busy) return RestoreOutcome.failed;
    final service = ref.read(purchaseServiceProvider);
    final analytics = ref.read(appAnalyticsProvider.notifier);
    _setBusy(busy: true);
    RestoreOutcome outcome;
    try {
      outcome = await service.restore();
    } on Object catch (error) {
      developer.log('restore failed', name: 'paywall', error: error);
      outcome = RestoreOutcome.failed;
    }
    if (outcome == RestoreOutcome.restoredPremium) {
      analytics.log(const AnalyticsEvent.restoreSuccess());
    }
    _setBusy(busy: false);
    return outcome;
  }
}
