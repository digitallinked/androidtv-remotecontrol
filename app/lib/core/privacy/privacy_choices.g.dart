// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'privacy_choices.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The stored [ConsentRegion].

@ProviderFor(ConsentRegionState)
final consentRegionStateProvider = ConsentRegionStateProvider._();

/// The stored [ConsentRegion].
final class ConsentRegionStateProvider
    extends $NotifierProvider<ConsentRegionState, ConsentRegion> {
  /// The stored [ConsentRegion].
  ConsentRegionStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'consentRegionStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$consentRegionStateHash();

  @$internal
  @override
  ConsentRegionState create() => ConsentRegionState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConsentRegion value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConsentRegion>(value),
    );
  }
}

String _$consentRegionStateHash() =>
    r'fb6a62e529c7426b61ce72d001971f277ed70d23';

/// The stored [ConsentRegion].

abstract class _$ConsentRegionState extends $Notifier<ConsentRegion> {
  ConsentRegion build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ConsentRegion, ConsentRegion>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ConsentRegion, ConsentRegion>,
              ConsentRegion,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The resolved privacy choices; follows the settings and the region.

@ProviderFor(privacyChoices)
final privacyChoicesProvider = PrivacyChoicesProvider._();

/// The resolved privacy choices; follows the settings and the region.

final class PrivacyChoicesProvider
    extends $FunctionalProvider<PrivacyChoices, PrivacyChoices, PrivacyChoices>
    with $Provider<PrivacyChoices> {
  /// The resolved privacy choices; follows the settings and the region.
  PrivacyChoicesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'privacyChoicesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$privacyChoicesHash();

  @$internal
  @override
  $ProviderElement<PrivacyChoices> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PrivacyChoices create(Ref ref) {
    return privacyChoices(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PrivacyChoices value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PrivacyChoices>(value),
    );
  }
}

String _$privacyChoicesHash() => r'0fe0f16b7807af09378b1a956cd4f115be00d033';
