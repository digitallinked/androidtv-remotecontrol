// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'consent_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's [ConsentService]: Google's UMP.

@ProviderFor(consentService)
final consentServiceProvider = ConsentServiceProvider._();

/// The app's [ConsentService]: Google's UMP.

final class ConsentServiceProvider
    extends $FunctionalProvider<ConsentService, ConsentService, ConsentService>
    with $Provider<ConsentService> {
  /// The app's [ConsentService]: Google's UMP.
  ConsentServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'consentServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$consentServiceHash();

  @$internal
  @override
  $ProviderElement<ConsentService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ConsentService create(Ref ref) {
    return consentService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConsentService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConsentService>(value),
    );
  }
}

String _$consentServiceHash() => r'31a0cde810652bd7ceb9f5e065d6b7ca3b548bf9';
