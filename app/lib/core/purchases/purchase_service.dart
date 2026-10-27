import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/app/flavor.dart';
import 'package:tv_remote/core/config/service_config.dart';
import 'package:tv_remote/core/purchases/revenuecat_purchase_service.dart';
import 'package:tv_remote/core/purchases/unavailable_purchase_service.dart';

part 'purchase_service.g.dart';

/// The Premium plans the app sells (Ruling P6-R10).
enum PremiumPlanKind {
  /// A subscription that renews every month.
  monthly('premium_monthly'),

  /// A subscription that renews every year.
  yearly('premium_yearly'),

  /// One payment, no subscription.
  lifetime('premium_lifetime');

  const PremiumPlanKind(this.productId);

  /// The store product id. It is also the value of the `product` analytics
  /// parameter.
  final String productId;
}

/// One plan on offer, with the price the store reports.
@immutable
class PremiumPlan {
  /// Creates a plan.
  const PremiumPlan({
    required this.kind,
    required this.priceString,
    required this.price,
    required this.currencyCode,
  });

  /// Which plan this is.
  final PremiumPlanKind kind;

  /// The price as the store formats it (`RM 4.99`).
  final String priceString;

  /// The price as a number, in [currencyCode].
  final double price;

  /// The ISO 4217 currency of [price].
  final String currencyCode;
}

/// The plans the store offers right now, in the order the paywall shows them.
@immutable
class PremiumOffer {
  /// Creates an offer.
  const PremiumOffer({required this.plans});

  /// The plans; a plan the store doesn't offer is missing.
  final List<PremiumPlan> plans;

  /// The plan of [kind], or `null` when the store doesn't offer it.
  PremiumPlan? plan(PremiumPlanKind kind) {
    for (final plan in plans) {
      if (plan.kind == kind) return plan;
    }
    return null;
  }
}

/// What the store says about the `premium` entitlement.
@immutable
class EntitlementSnapshot {
  /// Creates a snapshot.
  const EntitlementSnapshot({
    required this.active,
    this.expiresAt,
    this.willRenew = false,
  });

  /// Whether the entitlement is active.
  final bool active;

  /// When it ends (UTC), or `null` for a lifetime purchase while [active].
  final DateTime? expiresAt;

  /// Whether the subscription renews by itself.
  final bool willRenew;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EntitlementSnapshot &&
          other.active == active &&
          other.expiresAt == expiresAt &&
          other.willRenew == willRenew;

  @override
  int get hashCode => Object.hash(active, expiresAt, willRenew);

  @override
  String toString() =>
      'EntitlementSnapshot(active: $active, expiresAt: $expiresAt, '
      'willRenew: $willRenew)';
}

/// Why a purchase failed.
enum PurchaseFailure {
  /// The store couldn't be reached.
  network,

  /// This phone or account may not buy.
  notAllowed,

  /// The account already owns Premium.
  alreadyOwned,

  /// The store reported a problem.
  storeProblem,

  /// Anything else.
  unknown,
}

/// How a purchase ended.
@immutable
sealed class PurchaseOutcome {
  const PurchaseOutcome();
}

/// The purchase went through; Premium is [entitlement].
final class Purchased extends PurchaseOutcome {
  /// Creates the outcome.
  const Purchased(this.entitlement);

  /// The entitlement after the purchase.
  final EntitlementSnapshot entitlement;

  @override
  bool operator ==(Object other) =>
      other is Purchased && other.entitlement == entitlement;

  @override
  int get hashCode => entitlement.hashCode;
}

/// The user backed out. Nothing to say.
final class PurchaseCancelled extends PurchaseOutcome {
  /// Creates the outcome.
  const PurchaseCancelled();
}

/// The store is waiting for approval (a parent, or a slow payment method).
final class PurchasePending extends PurchaseOutcome {
  /// Creates the outcome.
  const PurchasePending();
}

/// The purchase failed for [failure].
final class PurchaseFailed extends PurchaseOutcome {
  /// Creates the outcome.
  const PurchaseFailed(this.failure);

  /// Why.
  final PurchaseFailure failure;

  @override
  bool operator ==(Object other) =>
      other is PurchaseFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'PurchaseFailed($failure)';
}

/// How a restore ended.
enum RestoreOutcome {
  /// The account has Premium and it is active again.
  restoredPremium,

  /// The store has no Premium purchase for this account.
  nothingToRestore,

  /// The store couldn't be asked.
  failed,
}

/// Premium purchases, behind our own interface so no RevenueCat type reaches
/// a provider signature or a widget.
///
/// No method throws: an error becomes `null`, a failed outcome or no event.
abstract interface class PurchaseService {
  /// Whether there is a store to ask. `false` for a build with no key.
  bool get isConfigured;

  /// Starts the SDK and asks for the current entitlement. The answer arrives
  /// on [entitlements]. Safe to call again after a failure.
  Future<void> configure();

  /// The entitlement every time the store reports it.
  Stream<EntitlementSnapshot> get entitlements;

  /// The plans on offer, or `null` when there are none or the store can't be
  /// reached.
  Future<PremiumOffer?> loadOffer();

  /// Buys the plan [kind].
  Future<PurchaseOutcome> purchase(PremiumPlanKind kind);

  /// Asks the store for this account's earlier purchases.
  ///
  /// The outcome carries no entitlement. An implementation that answers
  /// [RestoreOutcome.restoredPremium] must first push the entitlement it
  /// found onto [entitlements], where `Premium` applies it and writes the
  /// cache.
  Future<RestoreOutcome> restore();
}

/// How much cheaper the yearly plan is than twelve monthly ones, in whole
/// percent rounded down, or `null` when it isn't cheaper (Ruling P6-R11).
///
/// The arithmetic runs on prices in hundredths, so a price such as 24.00
/// can't land a hair under a whole number.
int? savePercent({required double monthly, required double yearly}) {
  final monthlyCents = (monthly * 100).round();
  final yearlyCents = (yearly * 100).round();
  if (monthlyCents <= 0 || yearlyCents <= 0) return null;
  final twelve = 12 * monthlyCents;
  if (yearlyCents >= twelve) return null;
  return (twelve - yearlyCents) * 100 ~/ twelve;
}

/// The app's [PurchaseService]: RevenueCat when this build has a key for the
/// platform, otherwise one that offers nothing (Ruling P6-R2).
@Riverpod(keepAlive: true)
PurchaseService purchaseService(Ref ref) {
  final key = ref
      .watch(serviceConfigProvider)
      .revenueCatKey(defaultTargetPlatform);
  if (key == null) return const UnavailablePurchaseService();
  final service = RevenueCatPurchaseService(
    apiKey: key,
    debugLogs: ref.watch(flavorProvider) == Flavor.dev,
  );
  ref.onDispose(service.dispose);
  return service;
}
