// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ads_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's [AdsSdk]: Google Mobile Ads.

@ProviderFor(adsSdk)
final adsSdkProvider = AdsSdkProvider._();

/// The app's [AdsSdk]: Google Mobile Ads.

final class AdsSdkProvider extends $FunctionalProvider<AdsSdk, AdsSdk, AdsSdk>
    with $Provider<AdsSdk> {
  /// The app's [AdsSdk]: Google Mobile Ads.
  AdsSdkProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'adsSdkProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$adsSdkHash();

  @$internal
  @override
  $ProviderElement<AdsSdk> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AdsSdk create(Ref ref) {
    return adsSdk(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AdsSdk value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AdsSdk>(value),
    );
  }
}

String _$adsSdkHash() => r'5277322c8a3d6fc431bb47574d954cb270fb8441';

/// The ad unit ids of this build, flavor and platform.

@ProviderFor(adUnitIds)
final adUnitIdsProvider = AdUnitIdsProvider._();

/// The ad unit ids of this build, flavor and platform.

final class AdUnitIdsProvider
    extends $FunctionalProvider<AdUnitIds, AdUnitIds, AdUnitIds>
    with $Provider<AdUnitIds> {
  /// The ad unit ids of this build, flavor and platform.
  AdUnitIdsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'adUnitIdsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$adUnitIdsHash();

  @$internal
  @override
  $ProviderElement<AdUnitIds> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AdUnitIds create(Ref ref) {
    return adUnitIds(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AdUnitIds value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AdUnitIds>(value),
    );
  }
}

String _$adUnitIdsHash() => r'c6af29ff44eca5bf6e8adeb5a088e7a701228b37';

/// Decides when the ads SDK may start and when a banner may show (Ruling
/// P6-R9).

@ProviderFor(AdsController)
final adsControllerProvider = AdsControllerProvider._();

/// Decides when the ads SDK may start and when a banner may show (Ruling
/// P6-R9).
final class AdsControllerProvider
    extends $NotifierProvider<AdsController, void> {
  /// Decides when the ads SDK may start and when a banner may show (Ruling
  /// P6-R9).
  AdsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'adsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$adsControllerHash();

  @$internal
  @override
  AdsController create() => AdsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$adsControllerHash() => r'73ba870a0f997da1135cb708d3da1fd3fab838ae';

/// Decides when the ads SDK may start and when a banner may show (Ruling
/// P6-R9).

abstract class _$AdsController extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
