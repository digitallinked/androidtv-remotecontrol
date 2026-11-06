import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart'
    show
        Package,
        PackageType,
        PresentedOfferingContext,
        PurchasesErrorCode,
        StoreProduct;
import 'package:tv_remote/core/purchases/purchase_service.dart';
import 'package:tv_remote/core/purchases/revenuecat_purchase_service.dart';

void main() {
  // Ruling P9-C14: every failure the paywall shows is recorded, and the
  // plugin's error goes to the hook, not out of the service.
  group('store failures', () {
    late List<String> reasons;
    late RevenueCatPurchaseService service;

    /// The plugin's channel, answering [method] with [answer].
    void plugin(String method, Future<Object?> Function() answer) {
      TestWidgetsFlutterBinding.ensureInitialized();
      const channel = MethodChannel('purchases_flutter');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            ..setMockMethodCallHandler(
              channel,
              (call) async => call.method == method ? answer() : null,
            );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    }

    PlatformException storeError(PurchasesErrorCode code) =>
        PlatformException(code: '${code.index}');

    setUp(() {
      reasons = [];
      service =
          RevenueCatPurchaseService(
            apiKey: 'fake-key',
            debugLogs: false,
            onError: (_, _, reason) => reasons.add(reason),
          )..debugUsePackage(
            PremiumPlanKind.monthly,
            const Package(
              'monthly',
              PackageType.monthly,
              StoreProduct('id', 'description', 'title', 1, '1', 'USD'),
              PresentedOfferingContext('offering', null, null),
            ),
          );
      addTearDown(service.dispose);
    });

    test('a_failed_store_setup_is_recorded', () async {
      plugin(
        'setupPurchases',
        () async => throw storeError(
          PurchasesErrorCode.configurationError,
        ),
      );

      await service.configure();

      expect(reasons, ['purchases']);
    });

    test('failed_offerings_are_recorded', () async {
      plugin(
        'getOfferings',
        () async => throw storeError(
          PurchasesErrorCode.networkError,
        ),
      );

      expect(await service.loadOffer(), isNull);

      expect(reasons, ['purchases']);
    });

    test('a_store_failure_during_a_purchase_is_recorded', () async {
      plugin(
        'purchasePackage',
        () async => throw storeError(
          PurchasesErrorCode.storeProblemError,
        ),
      );

      final outcome = await service.purchase(PremiumPlanKind.monthly);

      expect(outcome, const PurchaseFailed(PurchaseFailure.storeProblem));
      expect(reasons, ['purchases']);
    });

    test('an_unexpected_purchase_error_is_recorded', () async {
      plugin('purchasePackage', () async => 'not a purchase result');

      final outcome = await service.purchase(PremiumPlanKind.monthly);

      expect(outcome, const PurchaseFailed(PurchaseFailure.unknown));
      expect(reasons, ['purchases']);
    });

    test('a_cancelled_or_pending_purchase_is_not_a_failure', () async {
      for (final code in const [
        PurchasesErrorCode.purchaseCancelledError,
        PurchasesErrorCode.paymentPendingError,
      ]) {
        plugin('purchasePackage', () async => throw storeError(code));

        await service.purchase(PremiumPlanKind.monthly);

        expect(reasons, isEmpty, reason: '$code');
      }
    });

    test('a_failed_restore_is_recorded', () async {
      plugin(
        'restorePurchases',
        () async => throw storeError(
          PurchasesErrorCode.networkError,
        ),
      );

      expect(await service.restore(), RestoreOutcome.failed);

      expect(reasons, ['purchases']);
    });
  });

  test('purchase_failure_codes_map_to_outcomes', () {
    PurchaseFailure? failureOf(PurchasesErrorCode code) {
      final outcome = purchaseOutcomeFor(code);
      return outcome is PurchaseFailed ? outcome.failure : null;
    }

    expect(
      purchaseOutcomeFor(PurchasesErrorCode.purchaseCancelledError),
      isA<PurchaseCancelled>(),
    );
    expect(
      purchaseOutcomeFor(PurchasesErrorCode.paymentPendingError),
      isA<PurchasePending>(),
    );
    expect(
      failureOf(PurchasesErrorCode.networkError),
      PurchaseFailure.network,
    );
    expect(
      failureOf(PurchasesErrorCode.offlineConnectionError),
      PurchaseFailure.network,
    );
    expect(
      failureOf(PurchasesErrorCode.purchaseNotAllowedError),
      PurchaseFailure.notAllowed,
    );
    expect(
      failureOf(PurchasesErrorCode.productAlreadyPurchasedError),
      PurchaseFailure.alreadyOwned,
    );
    expect(
      failureOf(PurchasesErrorCode.storeProblemError),
      PurchaseFailure.storeProblem,
    );
    // Everything else is "unknown", and nothing else is a success.
    for (final code in PurchasesErrorCode.values) {
      final outcome = purchaseOutcomeFor(code);
      expect(outcome, isNot(isA<Purchased>()), reason: '$code');
    }
    expect(
      failureOf(PurchasesErrorCode.invalidCredentialsError),
      PurchaseFailure.unknown,
    );
    expect(failureOf(PurchasesErrorCode.unknownError), PurchaseFailure.unknown);
  });

  test('entitlement_from_parses_utc_and_lifetime', () {
    final monthly = entitlementFrom(
      active: true,
      expirationDate: '2026-11-27T09:30:00Z',
      willRenew: true,
    );
    expect(monthly.active, isTrue);
    expect(monthly.willRenew, isTrue);
    expect(monthly.expiresAt, DateTime.utc(2026, 11, 27, 9, 30));
    expect(monthly.expiresAt!.isUtc, isTrue);

    // A zone offset becomes the same instant in UTC.
    final offset = entitlementFrom(
      active: true,
      expirationDate: '2026-11-27T17:30:00+08:00',
    );
    expect(offset.expiresAt, DateTime.utc(2026, 11, 27, 9, 30));
    expect(offset.expiresAt!.isUtc, isTrue);

    // No zone at all still means UTC.
    final bare = entitlementFrom(
      active: true,
      expirationDate: '2026-11-27T09:30:00',
    );
    expect(bare.expiresAt, DateTime.utc(2026, 11, 27, 9, 30));
    expect(bare.expiresAt!.isUtc, isTrue);

    // No expiration date on an active entitlement is a lifetime purchase.
    final lifetime = entitlementFrom(active: true);
    expect(lifetime.active, isTrue);
    expect(lifetime.expiresAt, isNull);
    expect(lifetime.willRenew, isFalse);

    expect(entitlementFrom(active: false).active, isFalse);
  });

  test('an_unreadable_expiry_is_an_error_never_a_lifetime_purchase', () {
    expect(
      () => entitlementFrom(active: true, expirationDate: 'soon'),
      throwsFormatException,
    );
    expect(
      () => entitlementFrom(active: true, expirationDate: ''),
      throwsFormatException,
    );
  });

  test('an_unreadable_expiry_gives_no_answer_so_the_cache_stands', () {
    // The adapter drops such an answer (and logs it), so Premium keeps the
    // last value it knew instead of caching "free" or "lifetime".
    expect(
      tryEntitlementFrom(active: true, expirationDate: 'soon'),
      isNull,
    );
    expect(
      tryEntitlementFrom(
        active: true,
        expirationDate: '2026-11-27T09:30:00Z',
      )?.expiresAt,
      DateTime.utc(2026, 11, 27, 9, 30),
    );
    expect(tryEntitlementFrom(active: true)?.active, isTrue);
    expect(tryEntitlementFrom(active: false)?.active, isFalse);
  });

  test('save_percent_is_honest', () {
    expect(savePercent(monthly: 4.99, yearly: 29.99), 49);
    expect(savePercent(monthly: 2, yearly: 24), isNull);
    expect(savePercent(monthly: 2, yearly: 30), isNull);
    // Rounds down, never up.
    expect(savePercent(monthly: 10, yearly: 100.01), 16);
    // A price that makes the arithmetic land on a whole number still does.
    expect(savePercent(monthly: 1, yearly: 8.4), 30);
    expect(savePercent(monthly: 0, yearly: 10), isNull);
    expect(savePercent(monthly: -1, yearly: 1), isNull);
  });

  test('product_ids_are_the_store_ids', () {
    expect(
      [for (final kind in PremiumPlanKind.values) kind.productId],
      ['premium_monthly', 'premium_yearly', 'premium_lifetime'],
    );
  });
}
