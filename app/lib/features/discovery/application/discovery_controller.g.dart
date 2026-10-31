// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discovery_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Searches the network for TVs while the discovery screen is open.
///
/// The search stops when the screen goes away.

@ProviderFor(DiscoveryController)
final discoveryControllerProvider = DiscoveryControllerProvider._();

/// Searches the network for TVs while the discovery screen is open.
///
/// The search stops when the screen goes away.
final class DiscoveryControllerProvider
    extends $NotifierProvider<DiscoveryController, DiscoveryState> {
  /// Searches the network for TVs while the discovery screen is open.
  ///
  /// The search stops when the screen goes away.
  DiscoveryControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'discoveryControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$discoveryControllerHash();

  @$internal
  @override
  DiscoveryController create() => DiscoveryController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DiscoveryState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DiscoveryState>(value),
    );
  }
}

String _$discoveryControllerHash() =>
    r'19d923266729f6714b35d50c4a8669b44cffa2ad';

/// Searches the network for TVs while the discovery screen is open.
///
/// The search stops when the screen goes away.

abstract class _$DiscoveryController extends $Notifier<DiscoveryState> {
  DiscoveryState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DiscoveryState, DiscoveryState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DiscoveryState, DiscoveryState>,
              DiscoveryState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
