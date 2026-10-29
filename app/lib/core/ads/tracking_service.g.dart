// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tracking_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's [TrackingService]: App Tracking Transparency on iOS, nothing
/// elsewhere.

@ProviderFor(trackingService)
final trackingServiceProvider = TrackingServiceProvider._();

/// The app's [TrackingService]: App Tracking Transparency on iOS, nothing
/// elsewhere.

final class TrackingServiceProvider
    extends
        $FunctionalProvider<TrackingService, TrackingService, TrackingService>
    with $Provider<TrackingService> {
  /// The app's [TrackingService]: App Tracking Transparency on iOS, nothing
  /// elsewhere.
  TrackingServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trackingServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trackingServiceHash();

  @$internal
  @override
  $ProviderElement<TrackingService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TrackingService create(Ref ref) {
    return trackingService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TrackingService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TrackingService>(value),
    );
  }
}

String _$trackingServiceHash() => r'6dff2bf640f0d2aa808e448d23d5c288192eba41';

/// The current tracking answer, for the Privacy choices page. It is asked
/// again each time the page watches it anew.

@ProviderFor(trackingStatus)
final trackingStatusProvider = TrackingStatusProvider._();

/// The current tracking answer, for the Privacy choices page. It is asked
/// again each time the page watches it anew.

final class TrackingStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<TrackingStatus>,
          TrackingStatus,
          FutureOr<TrackingStatus>
        >
    with $FutureModifier<TrackingStatus>, $FutureProvider<TrackingStatus> {
  /// The current tracking answer, for the Privacy choices page. It is asked
  /// again each time the page watches it anew.
  TrackingStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trackingStatusProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trackingStatusHash();

  @$internal
  @override
  $FutureProviderElement<TrackingStatus> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TrackingStatus> create(Ref ref) {
    return trackingStatus(ref);
  }
}

String _$trackingStatusHash() => r'abb4c92756152a3c0f9ae35ac37a595f5d1fcd51';
