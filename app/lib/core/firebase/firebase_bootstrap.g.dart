// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firebase_bootstrap.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether Firebase started. Startup overrides it; tests get
/// [FirebaseStatus.notConfigured].

@ProviderFor(firebaseStatus)
final firebaseStatusProvider = FirebaseStatusProvider._();

/// Whether Firebase started. Startup overrides it; tests get
/// [FirebaseStatus.notConfigured].

final class FirebaseStatusProvider
    extends $FunctionalProvider<FirebaseStatus, FirebaseStatus, FirebaseStatus>
    with $Provider<FirebaseStatus> {
  /// Whether Firebase started. Startup overrides it; tests get
  /// [FirebaseStatus.notConfigured].
  FirebaseStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'firebaseStatusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$firebaseStatusHash();

  @$internal
  @override
  $ProviderElement<FirebaseStatus> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FirebaseStatus create(Ref ref) {
    return firebaseStatus(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FirebaseStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FirebaseStatus>(value),
    );
  }
}

String _$firebaseStatusHash() => r'ca4c3a56d27fd0a634d5977441dc1a834f35f408';
