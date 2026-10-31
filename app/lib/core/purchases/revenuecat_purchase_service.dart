import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:tv_remote/core/purchases/purchase_service.dart';

/// The RevenueCat entitlement that means Premium.
const String premiumEntitlement = 'premium';

/// The outcome of a purchase that ended with [code] (Ruling P6-R10).
PurchaseOutcome purchaseOutcomeFor(PurchasesErrorCode code) => switch (code) {
  PurchasesErrorCode.purchaseCancelledError => const PurchaseCancelled(),
  PurchasesErrorCode.paymentPendingError => const PurchasePending(),
  PurchasesErrorCode.networkError ||
  PurchasesErrorCode.offlineConnectionError => const PurchaseFailed(
    PurchaseFailure.network,
  ),
  PurchasesErrorCode.purchaseNotAllowedError => const PurchaseFailed(
    PurchaseFailure.notAllowed,
  ),
  PurchasesErrorCode.productAlreadyPurchasedError => const PurchaseFailed(
    PurchaseFailure.alreadyOwned,
  ),
  PurchasesErrorCode.storeProblemError => const PurchaseFailed(
    PurchaseFailure.storeProblem,
  ),
  _ => const PurchaseFailed(PurchaseFailure.unknown),
};

/// The snapshot of an entitlement that is [active] and ends at
/// [expirationDate] (an ISO 8601 text from RevenueCat; `null` for a lifetime
/// purchase), parsed as UTC even when it carries no zone.
///
/// Throws a [FormatException] when [expirationDate] is there but can't be
/// read: an unreadable date is never taken for a lifetime purchase, and it is
/// no reason to call the user free either. See [tryEntitlementFrom].
EntitlementSnapshot entitlementFrom({
  required bool active,
  String? expirationDate,
  bool willRenew = false,
}) {
  if (expirationDate == null) {
    return EntitlementSnapshot(active: active, willRenew: willRenew);
  }
  final parsed = DateTime.tryParse(expirationDate);
  if (parsed == null) {
    throw const FormatException('unreadable entitlement expiry');
  }
  final utc = parsed.isUtc
      ? parsed
      : DateTime.utc(
          parsed.year,
          parsed.month,
          parsed.day,
          parsed.hour,
          parsed.minute,
          parsed.second,
          parsed.millisecond,
          parsed.microsecond,
        );
  return EntitlementSnapshot(
    active: active,
    expiresAt: utc,
    willRenew: willRenew,
  );
}

/// [entitlementFrom], or `null` (after a log line) when the expiry can't be
/// read. The adapter drops such an answer, so the last value the app knew,
/// and its cache, stand.
EntitlementSnapshot? tryEntitlementFrom({
  required bool active,
  String? expirationDate,
  bool willRenew = false,
}) {
  try {
    return entitlementFrom(
      active: active,
      expirationDate: expirationDate,
      willRenew: willRenew,
    );
  } on FormatException catch (error) {
    developer.log(
      'entitlement ignored',
      name: 'purchases',
      error: error.message,
    );
    return null;
  }
}

/// [PurchaseService] backed by RevenueCat's `purchases_flutter`.
///
/// This is the only file that imports the package. Users are anonymous: the
/// app never logs in and sends no attributes. Every method catches every
/// error, `MissingPluginException` included.
class RevenueCatPurchaseService implements PurchaseService {
  /// Creates the service for the public SDK key [apiKey]. It touches the
  /// platform only when [configure] is called. With [debugLogs] the SDK logs
  /// at debug level (the dev flavor).
  RevenueCatPurchaseService({required this.apiKey, required this.debugLogs});

  /// The public SDK key.
  final String apiKey;

  /// Whether the SDK logs at debug level.
  final bool debugLogs;

  final StreamController<EntitlementSnapshot> _entitlements =
      StreamController<EntitlementSnapshot>.broadcast();
  final Map<PremiumPlanKind, Package> _packages = {};
  Future<bool>? _configuring;

  @override
  bool get isConfigured => true;

  @override
  Stream<EntitlementSnapshot> get entitlements => _entitlements.stream;

  /// Closes [entitlements] and stops listening to RevenueCat.
  void dispose() {
    try {
      Purchases.removeCustomerInfoUpdateListener(_onCustomerInfo);
    } on Object {
      // The plugin may be missing; there is nothing to remove then.
    }
    unawaited(_entitlements.close().catchError((Object _) {}));
  }

  @override
  Future<void> configure() async {
    await _ready();
  }

  /// Configures the SDK once. A failure is forgotten, so the next call tries
  /// again.
  Future<bool> _ready() {
    final running = _configuring ??= _configureOnce();
    return running.then((ok) {
      if (!ok && identical(_configuring, running)) _configuring = null;
      return ok;
    });
  }

  Future<bool> _configureOnce() async {
    try {
      if (debugLogs) await Purchases.setLogLevel(LogLevel.debug);
      await Purchases.configure(PurchasesConfiguration(apiKey));
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfo);
    } on Object catch (error) {
      _log('configure failed', error);
      return false;
    }
    try {
      _onCustomerInfo(await Purchases.getCustomerInfo());
    } on Object catch (error) {
      // Offline: the cached entitlement stands until the SDK reports.
      _log('customer info failed', error);
    }
    return true;
  }

  void _onCustomerInfo(CustomerInfo info) {
    final snapshot = _snapshotOf(info);
    if (snapshot != null && !_entitlements.isClosed) {
      _entitlements.add(snapshot);
    }
  }

  /// What [info] says about Premium, or `null` when it can't be read.
  EntitlementSnapshot? _snapshotOf(CustomerInfo info) {
    final entitlement = info.entitlements.active[premiumEntitlement];
    if (entitlement == null) return const EntitlementSnapshot(active: false);
    return tryEntitlementFrom(
      active: true,
      expirationDate: entitlement.expirationDate,
      willRenew: entitlement.willRenew,
    );
  }

  @override
  Future<PremiumOffer?> loadOffer() async {
    try {
      if (!await _ready()) return null;
      final current = (await Purchases.getOfferings()).current;
      if (current == null) return null;
      final found = <PremiumPlanKind, Package>{};
      for (final package in current.availablePackages) {
        final kind = switch (package.packageType) {
          PackageType.monthly => PremiumPlanKind.monthly,
          PackageType.annual => PremiumPlanKind.yearly,
          PackageType.lifetime => PremiumPlanKind.lifetime,
          _ => null,
        };
        if (kind != null) found.putIfAbsent(kind, () => package);
      }
      _packages
        ..clear()
        ..addAll(found);
      final plans = [
        for (final kind in PremiumPlanKind.values)
          if (found[kind] case final package?)
            PremiumPlan(
              kind: kind,
              priceString: package.storeProduct.priceString,
              price: package.storeProduct.price,
              currencyCode: package.storeProduct.currencyCode,
            ),
      ];
      return plans.isEmpty ? null : PremiumOffer(plans: plans);
    } on Object catch (error) {
      _log('offerings failed', error);
      return null;
    }
  }

  @override
  Future<PurchaseOutcome> purchase(PremiumPlanKind kind) async {
    try {
      if (!await _ready()) {
        return const PurchaseFailed(PurchaseFailure.storeProblem);
      }
      final package = _packages[kind];
      if (package == null) return const PurchaseFailed(PurchaseFailure.unknown);
      final result = await Purchases.purchase(PurchaseParams.package(package));
      final snapshot = _snapshotOf(result.customerInfo);
      if (snapshot == null) return const PurchasePending();
      if (!_entitlements.isClosed) _entitlements.add(snapshot);
      // The store took the payment but RevenueCat doesn't show the
      // entitlement yet (or not readably); the answer arrives on
      // [entitlements] when it does.
      return snapshot.active ? Purchased(snapshot) : const PurchasePending();
    } on PlatformException catch (error) {
      return purchaseOutcomeFor(_codeOf(error));
    } on Object catch (error) {
      _log('purchase failed', error);
      return const PurchaseFailed(PurchaseFailure.unknown);
    }
  }

  @override
  Future<RestoreOutcome> restore() async {
    try {
      if (!await _ready()) return RestoreOutcome.failed;
      final snapshot = _snapshotOf(await Purchases.restorePurchases());
      if (snapshot == null) return RestoreOutcome.failed;
      if (!_entitlements.isClosed) _entitlements.add(snapshot);
      return snapshot.active
          ? RestoreOutcome.restoredPremium
          : RestoreOutcome.nothingToRestore;
    } on Object catch (error) {
      _log('restore failed', error);
      return RestoreOutcome.failed;
    }
  }

  PurchasesErrorCode _codeOf(PlatformException error) {
    try {
      return PurchasesErrorHelper.getErrorCode(error);
    } on Object {
      return PurchasesErrorCode.unknownError;
    }
  }

  void _log(String message, Object error) =>
      developer.log(message, name: 'purchases', error: error);
}
