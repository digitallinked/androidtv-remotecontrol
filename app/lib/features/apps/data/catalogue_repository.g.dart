// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalogue_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app catalogue, loaded once from the bundled asset.
///
/// The file stays under 40 KB: `rootBundle.loadString` decodes bigger strings
/// in an isolate, which never completes inside `testWidgets`.

@ProviderFor(catalogue)
final catalogueProvider = CatalogueProvider._();

/// The app catalogue, loaded once from the bundled asset.
///
/// The file stays under 40 KB: `rootBundle.loadString` decodes bigger strings
/// in an isolate, which never completes inside `testWidgets`.

final class CatalogueProvider
    extends
        $FunctionalProvider<
          AsyncValue<AppCatalogue>,
          AppCatalogue,
          FutureOr<AppCatalogue>
        >
    with $FutureModifier<AppCatalogue>, $FutureProvider<AppCatalogue> {
  /// The app catalogue, loaded once from the bundled asset.
  ///
  /// The file stays under 40 KB: `rootBundle.loadString` decodes bigger strings
  /// in an isolate, which never completes inside `testWidgets`.
  CatalogueProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
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

String _$catalogueHash() => r'cec8711683d6d2cca0d130fe78e23d14bff579f1';

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
