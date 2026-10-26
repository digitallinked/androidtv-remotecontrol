// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'haptics.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's [Haptics]; tests override it with a recorder.

@ProviderFor(haptics)
final hapticsProvider = HapticsProvider._();

/// The app's [Haptics]; tests override it with a recorder.

final class HapticsProvider
    extends $FunctionalProvider<Haptics, Haptics, Haptics>
    with $Provider<Haptics> {
  /// The app's [Haptics]; tests override it with a recorder.
  HapticsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hapticsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hapticsHash();

  @$internal
  @override
  $ProviderElement<Haptics> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Haptics create(Ref ref) {
    return haptics(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Haptics value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Haptics>(value),
    );
  }
}

String _$hapticsHash() => r'3edd891a23b08d86c5a3622336baf2cc9c328238';
