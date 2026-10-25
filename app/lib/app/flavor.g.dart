// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flavor.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The running flavor. Bootstrap must override it.

@ProviderFor(flavor)
final flavorProvider = FlavorProvider._();

/// The running flavor. Bootstrap must override it.

final class FlavorProvider extends $FunctionalProvider<Flavor, Flavor, Flavor>
    with $Provider<Flavor> {
  /// The running flavor. Bootstrap must override it.
  FlavorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'flavorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$flavorHash();

  @$internal
  @override
  $ProviderElement<Flavor> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Flavor create(Ref ref) {
    return flavor(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Flavor value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Flavor>(value),
    );
  }
}

String _$flavorHash() => r'a1ede97c9e97a13b83dd9c54bf14486c90a26217';
