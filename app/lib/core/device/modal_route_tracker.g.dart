// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'modal_route_tracker.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's [ModalRouteTracker], observing the router's navigator.

@ProviderFor(modalRouteTracker)
final modalRouteTrackerProvider = ModalRouteTrackerProvider._();

/// The app's [ModalRouteTracker], observing the router's navigator.

final class ModalRouteTrackerProvider
    extends
        $FunctionalProvider<
          ModalRouteTracker,
          ModalRouteTracker,
          ModalRouteTracker
        >
    with $Provider<ModalRouteTracker> {
  /// The app's [ModalRouteTracker], observing the router's navigator.
  ModalRouteTrackerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'modalRouteTrackerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$modalRouteTrackerHash();

  @$internal
  @override
  $ProviderElement<ModalRouteTracker> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ModalRouteTracker create(Ref ref) {
    return modalRouteTracker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ModalRouteTracker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ModalRouteTracker>(value),
    );
  }
}

String _$modalRouteTrackerHash() => r'3cd3eac917e5a7c2b2608cf8136f05991d9b5f55';
