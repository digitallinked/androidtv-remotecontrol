// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service_config.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The build's [ServiceConfig]. Startup overrides it; tests get
/// [ServiceConfig.none].

@ProviderFor(serviceConfig)
final serviceConfigProvider = ServiceConfigProvider._();

/// The build's [ServiceConfig]. Startup overrides it; tests get
/// [ServiceConfig.none].

final class ServiceConfigProvider
    extends $FunctionalProvider<ServiceConfig, ServiceConfig, ServiceConfig>
    with $Provider<ServiceConfig> {
  /// The build's [ServiceConfig]. Startup overrides it; tests get
  /// [ServiceConfig.none].
  ServiceConfigProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'serviceConfigProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$serviceConfigHash();

  @$internal
  @override
  $ProviderElement<ServiceConfig> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ServiceConfig create(Ref ref) {
    return serviceConfig(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ServiceConfig value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ServiceConfig>(value),
    );
  }
}

String _$serviceConfigHash() => r'bbd82dd38e361dc676cb5678b9ededaec54c5f9b';
