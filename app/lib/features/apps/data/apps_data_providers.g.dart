// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'apps_data_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The user's app shortcuts, stored in the local database. Widget tests
/// override it with an in-memory fake.

@ProviderFor(shortcutRepository)
final shortcutRepositoryProvider = ShortcutRepositoryProvider._();

/// The user's app shortcuts, stored in the local database. Widget tests
/// override it with an in-memory fake.

final class ShortcutRepositoryProvider
    extends
        $FunctionalProvider<
          ShortcutRepository,
          ShortcutRepository,
          ShortcutRepository
        >
    with $Provider<ShortcutRepository> {
  /// The user's app shortcuts, stored in the local database. Widget tests
  /// override it with an in-memory fake.
  ShortcutRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shortcutRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shortcutRepositoryHash();

  @$internal
  @override
  $ProviderElement<ShortcutRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ShortcutRepository create(Ref ref) {
    return shortcutRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShortcutRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShortcutRepository>(value),
    );
  }
}

String _$shortcutRepositoryHash() =>
    r'4f377d0d2352956d8d937507038dd73923eeeca3';

/// App usage counts, stored in the local database. Widget tests override it
/// with an in-memory fake.

@ProviderFor(appUsageRepository)
final appUsageRepositoryProvider = AppUsageRepositoryProvider._();

/// App usage counts, stored in the local database. Widget tests override it
/// with an in-memory fake.

final class AppUsageRepositoryProvider
    extends
        $FunctionalProvider<
          AppUsageRepository,
          AppUsageRepository,
          AppUsageRepository
        >
    with $Provider<AppUsageRepository> {
  /// App usage counts, stored in the local database. Widget tests override it
  /// with an in-memory fake.
  AppUsageRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appUsageRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appUsageRepositoryHash();

  @$internal
  @override
  $ProviderElement<AppUsageRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AppUsageRepository create(Ref ref) {
    return appUsageRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppUsageRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppUsageRepository>(value),
    );
  }
}

String _$appUsageRepositoryHash() =>
    r'ef3f70b43c82a52d755332388a8b2c93f2f7cbe6';
