// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wake_on_lan_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's [WakeOnLanService].

@ProviderFor(wakeOnLanService)
final wakeOnLanServiceProvider = WakeOnLanServiceProvider._();

/// The app's [WakeOnLanService].

final class WakeOnLanServiceProvider
    extends
        $FunctionalProvider<
          WakeOnLanService,
          WakeOnLanService,
          WakeOnLanService
        >
    with $Provider<WakeOnLanService> {
  /// The app's [WakeOnLanService].
  WakeOnLanServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'wakeOnLanServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$wakeOnLanServiceHash();

  @$internal
  @override
  $ProviderElement<WakeOnLanService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WakeOnLanService create(Ref ref) {
    return wakeOnLanService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WakeOnLanService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WakeOnLanService>(value),
    );
  }
}

String _$wakeOnLanServiceHash() => r'01eba0fece21385b2bf02057484f140125109634';

/// Whether this platform can send Wake-on-LAN packets: always on Android, and
/// on iOS only when [kIosWakeOnLanEnabled] is set. Where it is `false` the
/// power key explains how to turn the TV on by hand.

@ProviderFor(wakeOnLanAvailable)
final wakeOnLanAvailableProvider = WakeOnLanAvailableProvider._();

/// Whether this platform can send Wake-on-LAN packets: always on Android, and
/// on iOS only when [kIosWakeOnLanEnabled] is set. Where it is `false` the
/// power key explains how to turn the TV on by hand.

final class WakeOnLanAvailableProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether this platform can send Wake-on-LAN packets: always on Android, and
  /// on iOS only when [kIosWakeOnLanEnabled] is set. Where it is `false` the
  /// power key explains how to turn the TV on by hand.
  WakeOnLanAvailableProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'wakeOnLanAvailableProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$wakeOnLanAvailableHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return wakeOnLanAvailable(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$wakeOnLanAvailableHash() =>
    r'5b789e9c16e0fc8e7ac980c6aa76a36e302a1959';
