// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'page_route_observer.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Tells screens when another full page covers them or leaves again. Only
/// page routes count: a sheet or dialog over a screen is not "leaving" it
/// (Ruling P4-R14). Registered on the router in `app/router.dart`.
///
/// It lives here, not next to the router, so `core/` never imports `app/`.

@ProviderFor(pageRouteObserver)
final pageRouteObserverProvider = PageRouteObserverProvider._();

/// Tells screens when another full page covers them or leaves again. Only
/// page routes count: a sheet or dialog over a screen is not "leaving" it
/// (Ruling P4-R14). Registered on the router in `app/router.dart`.
///
/// It lives here, not next to the router, so `core/` never imports `app/`.

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
  /// (Ruling P4-R14). Registered on the router in `app/router.dart`.
  ///
  /// It lives here, not next to the router, so `core/` never imports `app/`.
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
