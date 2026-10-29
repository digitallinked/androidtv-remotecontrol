// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_gate.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether this app version is older than the configured
/// `min_supported_version` and must be updated (Ruling P6-R7).
///
/// `false` while the app info is loading, when it can't be read, and for a
/// malformed version on either side: the gate never blocks by mistake.

@ProviderFor(updateRequired)
final updateRequiredProvider = UpdateRequiredProvider._();

/// Whether this app version is older than the configured
/// `min_supported_version` and must be updated (Ruling P6-R7).
///
/// `false` while the app info is loading, when it can't be read, and for a
/// malformed version on either side: the gate never blocks by mistake.

final class UpdateRequiredProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether this app version is older than the configured
  /// `min_supported_version` and must be updated (Ruling P6-R7).
  ///
  /// `false` while the app info is loading, when it can't be read, and for a
  /// malformed version on either side: the gate never blocks by mistake.
  UpdateRequiredProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateRequiredProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateRequiredHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return updateRequired(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$updateRequiredHash() => r'af59dc0588665fe7998bae984bb591de1ffe97c5';
