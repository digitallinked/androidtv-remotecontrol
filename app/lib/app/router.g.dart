// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The route to open first. Bootstrap must override it with the result of
/// [resolveInitialLocation].

@ProviderFor(initialLocation)
final initialLocationProvider = InitialLocationProvider._();

/// The route to open first. Bootstrap must override it with the result of
/// [resolveInitialLocation].

final class InitialLocationProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  /// The route to open first. Bootstrap must override it with the result of
  /// [resolveInitialLocation].
  InitialLocationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'initialLocationProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$initialLocationHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return initialLocation(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$initialLocationHash() => r'fe44ee17d256bb5c43dfdf6cf430600bc2740bdc';

/// The app's router.

@ProviderFor(appRouter)
final appRouterProvider = AppRouterProvider._();

/// The app's router.

final class AppRouterProvider
    extends $FunctionalProvider<GoRouter, GoRouter, GoRouter>
    with $Provider<GoRouter> {
  /// The app's router.
  AppRouterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appRouterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appRouterHash();

  @$internal
  @override
  $ProviderElement<GoRouter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GoRouter create(Ref ref) {
    return appRouter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoRouter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoRouter>(value),
    );
  }
}

String _$appRouterHash() => r'0a708834c513ef7b6bcc0271971edaf8ef509ec1';
