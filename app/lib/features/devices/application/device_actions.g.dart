// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The [DeviceActions] for the widgets.

@ProviderFor(deviceActions)
final deviceActionsProvider = DeviceActionsProvider._();

/// The [DeviceActions] for the widgets.

final class DeviceActionsProvider
    extends $FunctionalProvider<DeviceActions, DeviceActions, DeviceActions>
    with $Provider<DeviceActions> {
  /// The [DeviceActions] for the widgets.
  DeviceActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceActionsHash();

  @$internal
  @override
  $ProviderElement<DeviceActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DeviceActions create(Ref ref) {
    return deviceActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeviceActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeviceActions>(value),
    );
  }
}

String _$deviceActionsHash() => r'1b4d341e3bb02c5b747e5c0072715d7bd1fdafe9';
