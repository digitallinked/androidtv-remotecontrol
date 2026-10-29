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

/// Reports each screen to analytics by its route name. It is built here, not
/// in `core/`, because the names are `AppRouteNames`.

@ProviderFor(analyticsRouteObserver)
final analyticsRouteObserverProvider = AnalyticsRouteObserverProvider._();

/// Reports each screen to analytics by its route name. It is built here, not
/// in `core/`, because the names are `AppRouteNames`.

final class AnalyticsRouteObserverProvider
    extends
        $FunctionalProvider<
          AnalyticsRouteObserver,
          AnalyticsRouteObserver,
          AnalyticsRouteObserver
        >
    with $Provider<AnalyticsRouteObserver> {
  /// Reports each screen to analytics by its route name. It is built here, not
  /// in `core/`, because the names are `AppRouteNames`.
  AnalyticsRouteObserverProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'analyticsRouteObserverProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$analyticsRouteObserverHash();

  @$internal
  @override
  $ProviderElement<AnalyticsRouteObserver> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AnalyticsRouteObserver create(Ref ref) {
    return analyticsRouteObserver(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AnalyticsRouteObserver value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AnalyticsRouteObserver>(value),
    );
  }
}

String _$analyticsRouteObserverHash() =>
    r'65f56320cab70cf839156a806eab79f5770c8847';

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

String _$appRouterHash() => r'7094ff035b8f17585a046f8ed9c0ca4833e6cdea';
