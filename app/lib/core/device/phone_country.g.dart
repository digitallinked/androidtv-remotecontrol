// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'phone_country.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// [readPhoneCountry]'s answer, read once at startup (`bootstrap`).

@ProviderFor(phoneCountry)
final phoneCountryProvider = PhoneCountryProvider._();

/// [readPhoneCountry]'s answer, read once at startup (`bootstrap`).

final class PhoneCountryProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// [readPhoneCountry]'s answer, read once at startup (`bootstrap`).
  PhoneCountryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'phoneCountryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$phoneCountryHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return phoneCountry(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$phoneCountryHash() => r'c20602b830d8a8fcb50c035bb1b9dadac52c9fef';
