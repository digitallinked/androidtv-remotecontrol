import 'package:flutter/widgets.dart';

/// Reports each full page that becomes visible, by its route name.
///
/// go_router puts `GoRoute.name` into the page's name, so
/// `route.settings.name` is the parameter-free name (`edit_device`), never
/// the path (`/devices/Living%20Room`): a TV's name can't leak into a screen
/// view. Only page routes count, and only names in [screenNames]: sheets,
/// dialogs and unknown routes are ignored (Ruling P6-R6).
class AnalyticsRouteObserver extends NavigatorObserver {
  /// Creates the observer: [onScreen] is called with each screen's name, for
  /// the names in [screenNames].
  AnalyticsRouteObserver({required this.screenNames, required this.onScreen});

  /// The route names that are screens.
  final Set<String> screenNames;

  /// Receives the name of the screen that is now showing.
  final void Function(String routeName) onScreen;

  void _report(Route<dynamic>? route) {
    if (route is! PageRoute<dynamic>) return;
    final name = route.settings.name;
    if (name != null && screenNames.contains(name)) onScreen(name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _report(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _report(newRoute);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Closing a sheet or a dialog shows the same screen again.
    if (route is PageRoute<dynamic>) _report(previousRoute);
  }
}
