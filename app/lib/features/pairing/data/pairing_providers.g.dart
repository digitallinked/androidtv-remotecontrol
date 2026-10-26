// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pairing_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The factory of pairing clients.

@ProviderFor(pairingClientFactory)
final pairingClientFactoryProvider = PairingClientFactoryProvider._();

/// The factory of pairing clients.

final class PairingClientFactoryProvider
    extends
        $FunctionalProvider<
          PairingClientFactory,
          PairingClientFactory,
          PairingClientFactory
        >
    with $Provider<PairingClientFactory> {
  /// The factory of pairing clients.
  PairingClientFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pairingClientFactoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pairingClientFactoryHash();

  @$internal
  @override
  $ProviderElement<PairingClientFactory> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PairingClientFactory create(Ref ref) {
    return pairingClientFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PairingClientFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PairingClientFactory>(value),
    );
  }
}

String _$pairingClientFactoryHash() =>
    r'561411facc488f9188282448242c71bf972a47b2';

/// The TV to pair when the route carries only its service name (the app was
/// restored, or the link was opened by hand).
///
/// It tries the saved TV, then an IP address typed in earlier
/// (`manual:<ip>`), then a look-up on the network. It is `null` when the TV
/// can't be found.

@ProviderFor(pairingTarget)
final pairingTargetProvider = PairingTargetFamily._();

/// The TV to pair when the route carries only its service name (the app was
/// restored, or the link was opened by hand).
///
/// It tries the saved TV, then an IP address typed in earlier
/// (`manual:<ip>`), then a look-up on the network. It is `null` when the TV
/// can't be found.

final class PairingTargetProvider
    extends
        $FunctionalProvider<
          AsyncValue<DiscoveredTv?>,
          DiscoveredTv?,
          FutureOr<DiscoveredTv?>
        >
    with $FutureModifier<DiscoveredTv?>, $FutureProvider<DiscoveredTv?> {
  /// The TV to pair when the route carries only its service name (the app was
  /// restored, or the link was opened by hand).
  ///
  /// It tries the saved TV, then an IP address typed in earlier
  /// (`manual:<ip>`), then a look-up on the network. It is `null` when the TV
  /// can't be found.
  PairingTargetProvider._({
    required PairingTargetFamily super.from,
    required String super.argument,
  }) : super(
         retry: noRetry,
         name: r'pairingTargetProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$pairingTargetHash();

  @override
  String toString() {
    return r'pairingTargetProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<DiscoveredTv?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DiscoveredTv?> create(Ref ref) {
    final argument = this.argument as String;
    return pairingTarget(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PairingTargetProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$pairingTargetHash() => r'7fb257bd6af49535663a23e0e84574c1ab1ac108';

/// The TV to pair when the route carries only its service name (the app was
/// restored, or the link was opened by hand).
///
/// It tries the saved TV, then an IP address typed in earlier
/// (`manual:<ip>`), then a look-up on the network. It is `null` when the TV
/// can't be found.

final class PairingTargetFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<DiscoveredTv?>, String> {
  PairingTargetFamily._()
    : super(
        retry: noRetry,
        name: r'pairingTargetProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The TV to pair when the route carries only its service name (the app was
  /// restored, or the link was opened by hand).
  ///
  /// It tries the saved TV, then an IP address typed in earlier
  /// (`manual:<ip>`), then a look-up on the network. It is `null` when the TV
  /// can't be found.

  PairingTargetProvider call(String serviceName) =>
      PairingTargetProvider._(argument: serviceName, from: this);

  @override
  String toString() => r'pairingTargetProvider';
}
