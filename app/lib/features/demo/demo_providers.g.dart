// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'demo_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the simulated demo TV is the active target.

@ProviderFor(isDemoActive)
final isDemoActiveProvider = IsDemoActiveProvider._();

/// Whether the simulated demo TV is the active target.

final class IsDemoActiveProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether the simulated demo TV is the active target.
  IsDemoActiveProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isDemoActiveProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isDemoActiveHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return isDemoActive(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isDemoActiveHash() => r'b4fb93e57e0568c6709cce8e9e7992cdec033429';

/// What the demo TV was last asked to do, then every new action; `null`
/// before the first one, and for a session that is not the demo TV.
///
/// This is the only place that checks the session's type: the rest of the UI
/// reads `RemoteSession.isDemo` and this provider.

@ProviderFor(demoActivity)
final demoActivityProvider = DemoActivityProvider._();

/// What the demo TV was last asked to do, then every new action; `null`
/// before the first one, and for a session that is not the demo TV.
///
/// This is the only place that checks the session's type: the rest of the UI
/// reads `RemoteSession.isDemo` and this provider.

final class DemoActivityProvider
    extends
        $FunctionalProvider<
          AsyncValue<DemoAction?>,
          DemoAction?,
          Stream<DemoAction?>
        >
    with $FutureModifier<DemoAction?>, $StreamProvider<DemoAction?> {
  /// What the demo TV was last asked to do, then every new action; `null`
  /// before the first one, and for a session that is not the demo TV.
  ///
  /// This is the only place that checks the session's type: the rest of the UI
  /// reads `RemoteSession.isDemo` and this provider.
  DemoActivityProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'demoActivityProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$demoActivityHash();

  @$internal
  @override
  $StreamProviderElement<DemoAction?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<DemoAction?> create(Ref ref) {
    return demoActivity(ref);
  }
}

String _$demoActivityHash() => r'aab32e4707f47fa940d7ae0044e4dd8d4c5d5015';
