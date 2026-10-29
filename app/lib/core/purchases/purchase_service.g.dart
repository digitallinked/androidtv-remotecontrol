// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'purchase_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's [PurchaseService]: RevenueCat when this build has a key for the
/// platform, otherwise one that offers nothing (Ruling P6-R2).

@ProviderFor(purchaseService)
final purchaseServiceProvider = PurchaseServiceProvider._();

/// The app's [PurchaseService]: RevenueCat when this build has a key for the
/// platform, otherwise one that offers nothing (Ruling P6-R2).

final class PurchaseServiceProvider
    extends
        $FunctionalProvider<PurchaseService, PurchaseService, PurchaseService>
    with $Provider<PurchaseService> {
  /// The app's [PurchaseService]: RevenueCat when this build has a key for the
  /// platform, otherwise one that offers nothing (Ruling P6-R2).
  PurchaseServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'purchaseServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$purchaseServiceHash();

  @$internal
  @override
  $ProviderElement<PurchaseService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PurchaseService create(Ref ref) {
    return purchaseService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PurchaseService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PurchaseService>(value),
    );
  }
}

String _$purchaseServiceHash() => r'84d86d996ba4e6cfcdaa3a266dffecaf6f73e92f';
