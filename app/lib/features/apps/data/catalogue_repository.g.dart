// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalogue_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The raw catalogue JSON, read from the bundled asset. Tests override it.
///
/// The file stays under 40 KB: `rootBundle.loadString` decodes bigger strings
/// in an isolate, which never completes inside `testWidgets`.

@ProviderFor(catalogueSource)
final catalogueSourceProvider = CatalogueSourceProvider._();

/// The raw catalogue JSON, read from the bundled asset. Tests override it.
///
/// The file stays under 40 KB: `rootBundle.loadString` decodes bigger strings
/// in an isolate, which never completes inside `testWidgets`.

final class CatalogueSourceProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  /// The raw catalogue JSON, read from the bundled asset. Tests override it.
  ///
  /// The file stays under 40 KB: `rootBundle.loadString` decodes bigger strings
  /// in an isolate, which never completes inside `testWidgets`.
  CatalogueSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'catalogueSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$catalogueSourceHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return catalogueSource(ref);
  }
}

String _$catalogueSourceHash() => r'24051bfd4ee48b679fbea237002a3c6cb052718e';

/// The app catalogue, parsed once from [catalogueSourceProvider]. A corrupt
/// file surfaces as an error state at once (a bundled file never fixes
/// itself, so no retry).

@ProviderFor(catalogue)
final catalogueProvider = CatalogueProvider._();

/// The app catalogue, parsed once from [catalogueSourceProvider]. A corrupt
/// file surfaces as an error state at once (a bundled file never fixes
/// itself, so no retry).

final class CatalogueProvider
    extends
        $FunctionalProvider<
          AsyncValue<AppCatalogue>,
          AppCatalogue,
          FutureOr<AppCatalogue>
        >
    with $FutureModifier<AppCatalogue>, $FutureProvider<AppCatalogue> {
  /// The app catalogue, parsed once from [catalogueSourceProvider]. A corrupt
  /// file surfaces as an error state at once (a bundled file never fixes
  /// itself, so no retry).
  CatalogueProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'catalogueProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$catalogueHash();

  @$internal
  @override
  $FutureProviderElement<AppCatalogue> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AppCatalogue> create(Ref ref) {
    return catalogue(ref);
  }
}

String _$catalogueHash() => r'73cd0ebd767d3f575f7f934341dca1a76fd78def';

/// The phone's region: the upper-case country code of the first system locale
/// that has one, or `null`.

@ProviderFor(deviceRegion)
final deviceRegionProvider = DeviceRegionProvider._();

/// The phone's region: the upper-case country code of the first system locale
/// that has one, or `null`.

final class DeviceRegionProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// The phone's region: the upper-case country code of the first system locale
  /// that has one, or `null`.
  DeviceRegionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceRegionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceRegionHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return deviceRegion(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$deviceRegionHash() => r'7d1be8818e7cfa16d8b38ed24bf9b2f6f1cf3219';
