// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discovery_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Creates the platform TV discovery. Tests override it with a fake.

@ProviderFor(tvDiscoveryFactory)
final tvDiscoveryFactoryProvider = TvDiscoveryFactoryProvider._();

/// Creates the platform TV discovery. Tests override it with a fake.

final class TvDiscoveryFactoryProvider
    extends
        $FunctionalProvider<
          TvDiscoveryFactory,
          TvDiscoveryFactory,
          TvDiscoveryFactory
        >
    with $Provider<TvDiscoveryFactory> {
  /// Creates the platform TV discovery. Tests override it with a fake.
  TvDiscoveryFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tvDiscoveryFactoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tvDiscoveryFactoryHash();

  @$internal
  @override
  $ProviderElement<TvDiscoveryFactory> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TvDiscoveryFactory create(Ref ref) {
    return tvDiscoveryFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TvDiscoveryFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TvDiscoveryFactory>(value),
    );
  }
}

String _$tvDiscoveryFactoryHash() =>
    r'3803a5b79f8774b8fb7aa7495dca41fc9a98b06e';

/// Finds a saved TV's current address by its mDNS service name.

@ProviderFor(hostResolver)
final hostResolverProvider = HostResolverProvider._();

/// Finds a saved TV's current address by its mDNS service name.

final class HostResolverProvider
    extends $FunctionalProvider<HostResolver, HostResolver, HostResolver>
    with $Provider<HostResolver> {
  /// Finds a saved TV's current address by its mDNS service name.
  HostResolverProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hostResolverProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hostResolverHash();

  @$internal
  @override
  $ProviderElement<HostResolver> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  HostResolver create(Ref ref) {
    return hostResolver(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HostResolver value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HostResolver>(value),
    );
  }
}

String _$hostResolverHash() => r'07f33eaf61bc2606ded7a81a4f6a74b08afd47a4';
