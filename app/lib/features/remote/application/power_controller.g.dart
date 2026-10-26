// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'power_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The [PowerController] for the active TV and the current settings.
///
/// AutoDispose, like [remoteActions] (whose instance it uses): the remote
/// screen keeps it alive with a listener. Rebuilt when the session or the
/// haptics setting changes.

@ProviderFor(powerController)
final powerControllerProvider = PowerControllerProvider._();

/// The [PowerController] for the active TV and the current settings.
///
/// AutoDispose, like [remoteActions] (whose instance it uses): the remote
/// screen keeps it alive with a listener. Rebuilt when the session or the
/// haptics setting changes.

final class PowerControllerProvider
    extends
        $FunctionalProvider<PowerController, PowerController, PowerController>
    with $Provider<PowerController> {
  /// The [PowerController] for the active TV and the current settings.
  ///
  /// AutoDispose, like [remoteActions] (whose instance it uses): the remote
  /// screen keeps it alive with a listener. Rebuilt when the session or the
  /// haptics setting changes.
  PowerControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'powerControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$powerControllerHash();

  @$internal
  @override
  $ProviderElement<PowerController> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PowerController create(Ref ref) {
    return powerController(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PowerController value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PowerController>(value),
    );
  }
}

String _$powerControllerHash() => r'959d4d0c50998821fd45a41bb32a13f88a52e873';
