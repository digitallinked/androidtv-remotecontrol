// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'screen_services.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's [ScreenWakeLock]; tests override it with a recorder.

@ProviderFor(screenWakeLock)
final screenWakeLockProvider = ScreenWakeLockProvider._();

/// The app's [ScreenWakeLock]; tests override it with a recorder.

final class ScreenWakeLockProvider
    extends $FunctionalProvider<ScreenWakeLock, ScreenWakeLock, ScreenWakeLock>
    with $Provider<ScreenWakeLock> {
  /// The app's [ScreenWakeLock]; tests override it with a recorder.
  ScreenWakeLockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'screenWakeLockProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$screenWakeLockHash();

  @$internal
  @override
  $ProviderElement<ScreenWakeLock> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ScreenWakeLock create(Ref ref) {
    return screenWakeLock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ScreenWakeLock value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ScreenWakeLock>(value),
    );
  }
}

String _$screenWakeLockHash() => r'f6f352404369b6a705c49626e1ba8c0cedf66584';

/// The app's [ScreenDimmer]; tests override it with a recorder.

@ProviderFor(screenDimmer)
final screenDimmerProvider = ScreenDimmerProvider._();

/// The app's [ScreenDimmer]; tests override it with a recorder.

final class ScreenDimmerProvider
    extends $FunctionalProvider<ScreenDimmer, ScreenDimmer, ScreenDimmer>
    with $Provider<ScreenDimmer> {
  /// The app's [ScreenDimmer]; tests override it with a recorder.
  ScreenDimmerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'screenDimmerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$screenDimmerHash();

  @$internal
  @override
  $ProviderElement<ScreenDimmer> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ScreenDimmer create(Ref ref) {
    return screenDimmer(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ScreenDimmer value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ScreenDimmer>(value),
    );
  }
}

String _$screenDimmerHash() => r'a1409b826beef8e871b641e13b7feabd7bdd92c1';
