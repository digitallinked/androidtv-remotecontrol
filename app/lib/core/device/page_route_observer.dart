import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'page_route_observer.g.dart';

/// Tells screens when another full page covers them or leaves again. Only
/// page routes count: a sheet or dialog over a screen is not "leaving" it
/// (Ruling P4-R14). Registered on the router in `app/router.dart`.
///
/// It lives here, not next to the router, so `core/` never imports `app/`.
@Riverpod(keepAlive: true)
RouteObserver<PageRoute<dynamic>> pageRouteObserver(Ref ref) =>
    RouteObserver<PageRoute<dynamic>>();
