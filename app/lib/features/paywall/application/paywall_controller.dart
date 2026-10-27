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

/// What the store is being asked for while the screen is busy.
enum PaywallBusy {
  /// A purchase is open.
  purchasing,

  /// Earlier purchases are being restored.
  restoring,
}

/// The plans are on screen.
final class PaywallReady extends PaywallState {
  /// Creates the state.
  const PaywallReady({
    required this.offer,
    required this.selected,
    this.busyWith,
    this.badgePercent,
  });

  /// The plans the store offers.
  final PremiumOffer offer;

  /// The plan Continue buys, or `null` when none is chosen yet (Lifetime is
  /// never pre-selected).
  final PremiumPlanKind? selected;

  /// What the store is being asked for, or `null` when nothing is.
  final PaywallBusy? busyWith;

  /// Whether a purchase or a restore is running.
  bool get busy => busyWith != null;

  /// The honest saving of the yearly plan to show as a badge, or `null`.
  final int? badgePercent;

  /// A copy with [selected] changed.
  PaywallReady withSelected(PremiumPlanKind kind) => PaywallReady(
    offer: offer,
    selected: kind,
    busyWith: busyWith,
    badgePercent: badgePercent,
  );

  /// A copy that is busy with [busy], or idle for `null`.
  PaywallReady withBusy(PaywallBusy? busy) => PaywallReady(
    offer: offer,
    selected: selected,
    busyWith: busy,
    badgePercent: badgePercent,
  );
}

/// The user already has Premium.
final class PaywallActive extends PaywallState {
  /// Creates the state.
  const PaywallActive(this.premium, {this.busyWith});

  /// The Premium state being shown.
  final PremiumState premium;

  /// What the store is being asked for, or `null` when nothing is.
  final PaywallBusy? busyWith;

  /// Whether a restore is running.
  bool get busy => busyWith != null;
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
  PaywallBusy? _busyWith;

  @override
  PaywallState build(PaywallSource source) {
    final service = ref.watch(purchaseServiceProvider);
    final variant = ref.read(appConfigProvider).paywallVariant;
    ref.listen<PremiumState>(premiumProvider, (previous, next) {
      if (next.isPremium) {
        // While the store is open the plans stay on screen: the screen
        // closes itself when the purchase ends, and `_setBusy` catches the
        // state up afterwards.
        if (state is PaywallReady && _busyWith != null) return;
        state = PaywallActive(next, busyWith: _busyWith);
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
      badgePercent: choice.badge,
    );
  }

  /// Chooses the plan Continue buys. Ignored while busy or when the store
  /// doesn't offer [kind].
  void select(PremiumPlanKind kind) {
    final current = state;
    if (current is! PaywallReady || current.busy) return;
    if (current.offer.plan(kind) == null) return;
    state = current.withSelected(kind);
  }

  /// Asks for the plans again after [PaywallUnavailable].
  void retry() {
    if (state is! PaywallUnavailable) return;
    _reload(ref.read(purchaseServiceProvider));
  }

  /// Marks the screen busy with [busy], or idle for `null`. Going idle also
  /// catches the state up with Premium, which may have arrived meanwhile.
  void _setBusy(PaywallBusy? busy) {
    _busyWith = busy;
    if (!ref.mounted) return;
    final current = state;
    final premium = ref.read(premiumProvider);
    state = switch (current) {
      PaywallReady() when busy == null && premium.isPremium => PaywallActive(
        premium,
      ),
      PaywallReady() => current.withBusy(busy),
      PaywallActive() => PaywallActive(current.premium, busyWith: busy),
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
    if (_busyWith != null || kind == null) return const PurchaseCancelled();

    // Everything the end of the purchase needs is taken now: the screen may
    // be closed while the store sheet is open.
    final service = ref.read(purchaseServiceProvider);
    final premium = ref.read(premiumProvider.notifier);
    final analytics = ref.read(appAnalyticsProvider.notifier);
    _setBusy(PaywallBusy.purchasing);
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
    _setBusy(null);
    return outcome;
  }

  /// Asks the store for earlier purchases. While it does, the screen is busy.
  ///
  /// Answers `null`, and does nothing, when the screen is already busy: the
  /// caller then says nothing. The entitlement a successful restore finds
  /// reaches [Premium] through the service's `entitlements` stream.
  Future<RestoreOutcome?> restore() async {
    if (_busyWith != null) return null;
    final service = ref.read(purchaseServiceProvider);
    final analytics = ref.read(appAnalyticsProvider.notifier);
    _setBusy(PaywallBusy.restoring);
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
    _setBusy(null);
    return outcome;
  }
}
