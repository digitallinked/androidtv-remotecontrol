// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tracking_preprompt.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds the [TrackingPreprompt] of this launch.

@ProviderFor(trackingPreprompt)
final trackingPrepromptProvider = TrackingPrepromptProvider._();

/// Holds the [TrackingPreprompt] of this launch.

final class TrackingPrepromptProvider
    extends
        $FunctionalProvider<
          TrackingPreprompt,
          TrackingPreprompt,
          TrackingPreprompt
        >
    with $Provider<TrackingPreprompt> {
  /// Holds the [TrackingPreprompt] of this launch.
  TrackingPrepromptProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trackingPrepromptProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trackingPrepromptHash();

  @$internal
  @override
  $ProviderElement<TrackingPreprompt> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TrackingPreprompt create(Ref ref) {
    return trackingPreprompt(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TrackingPreprompt value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TrackingPreprompt>(value),
    );
  }
}

String _$trackingPrepromptHash() => r'480c701377656c0b986f37fdbd3fbe2add56d83a';
