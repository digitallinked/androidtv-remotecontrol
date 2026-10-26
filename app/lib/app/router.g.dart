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

/// Tells screens when another full page covers them or leaves again. Only
/// page routes count: a sheet or dialog over a screen is not "leaving" it
/// (Ruling P4-R14). Registered on the router below.

@ProviderFor(pageRouteObserver)
final pageRouteObserverProvider = PageRouteObserverProvider._();

/// Tells screens when another full page covers them or leaves again. Only
/// page routes count: a sheet or dialog over a screen is not "leaving" it
/// (Ruling P4-R14). Registered on the router below.

final class PageRouteObserverProvider
    extends
        $FunctionalProvider<
          RouteObserver<PageRoute<dynamic>>,
          RouteObserver<PageRoute<dynamic>>,
          RouteObserver<PageRoute<dynamic>>
        >
    with $Provider<RouteObserver<PageRoute<dynamic>>> {
  /// Tells screens when another full page covers them or leaves again. Only
  /// page routes count: a sheet or dialog over a screen is not "leaving" it
  /// (Ruling P4-R14). Registered on the router below.
  PageRouteObserverProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pageRouteObserverProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pageRouteObserverHash();

  @$internal
  @override
  $ProviderElement<RouteObserver<PageRoute<dynamic>>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RouteObserver<PageRoute<dynamic>> create(Ref ref) {
    return pageRouteObserver(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RouteObserver<PageRoute<dynamic>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RouteObserver<PageRoute<dynamic>>>(
        value,
      ),
    );
  }
}

String _$pageRouteObserverHash() => r'98aedd591d03103b68c46c1c9ef279af416d0797';

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

String _$appRouterHash() => r'ea7f2d5d43b92ebb3466b8a0259fbbf358411ffe';
