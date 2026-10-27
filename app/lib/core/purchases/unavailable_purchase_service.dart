import 'package:tv_remote/core/purchases/purchase_service.dart';

/// The [PurchaseService] of a build with no RevenueCat key (the default, so a
/// clean clone runs with no accounts). It offers nothing and buys nothing, and
/// the cached entitlement is all the app has.
class UnavailablePurchaseService implements PurchaseService {
  /// Creates the service.
  const UnavailablePurchaseService();

  @override
  bool get isConfigured => false;

  @override
  Future<void> configure() async {}

  @override
  Stream<EntitlementSnapshot> get entitlements => const Stream.empty();

  @override
  Future<PremiumOffer?> loadOffer() async => null;

  @override
  Future<PurchaseOutcome> purchase(PremiumPlanKind kind) async =>
      const PurchaseFailed(PurchaseFailure.storeProblem);

  @override
  Future<RestoreOutcome> restore() async => RestoreOutcome.failed;
}
