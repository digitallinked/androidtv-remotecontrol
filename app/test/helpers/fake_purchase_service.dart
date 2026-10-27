import 'dart:async';

import 'package:tv_remote/core/purchases/purchase_service.dart';

/// A [PurchaseService] that answers from its fields and records the calls it
/// gets.
///
/// Emit an entitlement with [emit]; set [nextPurchase], [nextRestore] and
/// [offer] before the call that should see them. [holdPurchase] and
/// [holdRestore] keep a call open until the test completes them.
class FakePurchaseService implements PurchaseService {
  /// Creates a fake; every field can also be changed afterwards.
  FakePurchaseService({
    this.offer,
    this.isConfigured = true,
    this.nextPurchase = const PurchaseCancelled(),
    this.nextRestore = RestoreOutcome.nothingToRestore,
    this.restoreSnapshot,
    this.emitBeforePurchaseReturns = false,
    this.configureError,
    this.loadOfferError,
  });

  final StreamController<EntitlementSnapshot> _entitlements =
      StreamController<EntitlementSnapshot>.broadcast();

  @override
  bool isConfigured;

  /// What [loadOffer] answers.
  PremiumOffer? offer;

  /// What the next [purchase] answers.
  PurchaseOutcome nextPurchase;

  /// What the next [restore] answers.
  RestoreOutcome nextRestore;

  /// When set, a [restore] that answers `restoredPremium` emits it, as the
  /// real service does.
  EntitlementSnapshot? restoreSnapshot;

  /// Whether a purchase that answers [Purchased] first emits its entitlement
  /// on [entitlements], as the real service does before it returns.
  bool emitBeforePurchaseReturns;

  /// When set, [configure] throws it.
  Exception? configureError;

  /// When set, [loadOffer] throws it.
  Exception? loadOfferError;

  /// When set, [purchase] waits for it.
  Completer<void>? holdPurchase;

  /// When set, [restore] waits for it.
  Completer<void>? holdRestore;

  /// How many times [configure] was called.
  int configureCalls = 0;

  /// How many times [loadOffer] was called.
  int loadOfferCalls = 0;

  /// The plans [purchase] was called with, in order.
  final List<PremiumPlanKind> purchases = [];

  /// How many times [restore] was called.
  int restoreCalls = 0;

  /// Whether anything is listening to [entitlements].
  bool get hasListeners => _entitlements.hasListener;

  /// Sends [snapshot] to everyone listening to [entitlements].
  void emit(EntitlementSnapshot snapshot) => _entitlements.add(snapshot);

  @override
  Stream<EntitlementSnapshot> get entitlements => _entitlements.stream;

  @override
  Future<void> configure() async {
    configureCalls++;
    final error = configureError;
    if (error != null) throw error;
  }

  @override
  Future<PremiumOffer?> loadOffer() async {
    loadOfferCalls++;
    final error = loadOfferError;
    if (error != null) throw error;
    return offer;
  }

  @override
  Future<PurchaseOutcome> purchase(PremiumPlanKind kind) async {
    purchases.add(kind);
    final outcome = nextPurchase;
    if (emitBeforePurchaseReturns && outcome is Purchased) {
      emit(outcome.entitlement);
    }
    await holdPurchase?.future;
    return outcome;
  }

  @override
  Future<RestoreOutcome> restore() async {
    restoreCalls++;
    await holdRestore?.future;
    final snapshot = restoreSnapshot;
    if (nextRestore == RestoreOutcome.restoredPremium && snapshot != null) {
      emit(snapshot);
    }
    return nextRestore;
  }
}

/// The offer the paywall tests use: monthly RM 4.99, yearly RM 29.99 and
/// lifetime RM 59.90. A plan can be left out, and the yearly price changed.
PremiumOffer testOffer({
  double yearly = 29.99,
  bool monthly = true,
  bool hasYearly = true,
  bool lifetime = true,
}) => PremiumOffer(
  plans: [
    if (monthly)
      const PremiumPlan(
        kind: PremiumPlanKind.monthly,
        priceString: 'RM 4.99',
        price: 4.99,
        currencyCode: 'MYR',
      ),
    if (hasYearly)
      PremiumPlan(
        kind: PremiumPlanKind.yearly,
        priceString: 'RM ${yearly.toStringAsFixed(2)}',
        price: yearly,
        currencyCode: 'MYR',
      ),
    if (lifetime)
      const PremiumPlan(
        kind: PremiumPlanKind.lifetime,
        priceString: 'RM 59.90',
        price: 59.90,
        currencyCode: 'MYR',
      ),
  ],
);
