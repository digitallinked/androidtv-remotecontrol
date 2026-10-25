// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'storage_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The local database, opened on first use and closed with its container.

@ProviderFor(appDatabase)
final appDatabaseProvider = AppDatabaseProvider._();

/// The local database, opened on first use and closed with its container.

final class AppDatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  /// The local database, opened on first use and closed with its container.
  AppDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return appDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$appDatabaseHash() => r'365ef3f215d780c29a21b6328f0b547a8363c6a6';

/// Saved TVs, stored in [appDatabaseProvider].

@ProviderFor(deviceRepository)
final deviceRepositoryProvider = DeviceRepositoryProvider._();

/// Saved TVs, stored in [appDatabaseProvider].

final class DeviceRepositoryProvider
    extends
        $FunctionalProvider<
          DeviceRepository,
          DeviceRepository,
          DeviceRepository
        >
    with $Provider<DeviceRepository> {
  /// Saved TVs, stored in [appDatabaseProvider].
  DeviceRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceRepositoryHash();

  @$internal
  @override
  $ProviderElement<DeviceRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DeviceRepository create(Ref ref) {
    return deviceRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeviceRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeviceRepository>(value),
    );
  }
}

String _$deviceRepositoryHash() => r'7df67ea79988a0ad0d6b22e2f36e8aeef0556c32';

/// The opened settings store. Bootstrap must override it, because opening
/// the store is asynchronous.

@ProviderFor(settingsStore)
final settingsStoreProvider = SettingsStoreProvider._();

/// The opened settings store. Bootstrap must override it, because opening
/// the store is asynchronous.

final class SettingsStoreProvider
    extends $FunctionalProvider<SettingsStore, SettingsStore, SettingsStore>
    with $Provider<SettingsStore> {
  /// The opened settings store. Bootstrap must override it, because opening
  /// the store is asynchronous.
  SettingsStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsStoreHash();

  @$internal
  @override
  $ProviderElement<SettingsStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SettingsStore create(Ref ref) {
    return settingsStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SettingsStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SettingsStore>(value),
    );
  }
}

String _$settingsStoreHash() => r'145dc6573fdea05fd90f3f44a3f24accd462a2df';

/// The phone's client identity. This is the only provider of it, because the
/// store memoises the identity per instance.

@ProviderFor(identityStore)
final identityStoreProvider = IdentityStoreProvider._();

/// The phone's client identity. This is the only provider of it, because the
/// store memoises the identity per instance.

final class IdentityStoreProvider
    extends $FunctionalProvider<IdentityStore, IdentityStore, IdentityStore>
    with $Provider<IdentityStore> {
  /// The phone's client identity. This is the only provider of it, because the
  /// store memoises the identity per instance.
  IdentityStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'identityStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$identityStoreHash();

  @$internal
  @override
  $ProviderElement<IdentityStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  IdentityStore create(Ref ref) {
    return identityStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IdentityStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IdentityStore>(value),
    );
  }
}

String _$identityStoreHash() => r'c9dbe3f432e9a0df87cb372c2c5da2d57af1d7a9';
