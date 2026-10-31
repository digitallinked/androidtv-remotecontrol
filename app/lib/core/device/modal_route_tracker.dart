import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'modal_route_tracker.g.dart';

/// Knows whether a sheet, dialog or menu (a [PopupRoute]) is open on the
/// navigator it observes, and tells its listeners when that changes.
///
/// Widgets built above the navigator, such as the demo strip, aren't covered
/// by a modal's barrier; they read [modalOpen] to stay out of the way while a
/// modal has the user's attention. Registered on the router in
/// `app/router.dart`.
class ModalRouteTracker extends NavigatorObserver with ChangeNotifier {
  int _open = 0;

  /// Whether at least one popup route is on the navigator.
  bool get modalOpen => _open > 0;

  void _change(Route<dynamic>? route, int by) {
    if (route is! PopupRoute<dynamic>) return;
    final was = modalOpen;
    _open = (_open + by).clamp(0, 1 << 30);
    if (modalOpen == was) return;
    // A navigator can remove routes while it rebuilds (go_router replacing
    // the pages under a dialog). Listeners above it must not rebuild in the
    // middle of that build, so they hear about it after the frame.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _change(route, 1);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _change(route, -1);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _change(route, -1);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _change(oldRoute, -1);
    _change(newRoute, 1);
  }
}

/// The app's [ModalRouteTracker], observing the router's navigator.
@Riverpod(keepAlive: true)
ModalRouteTracker modalRouteTracker(Ref ref) {
  final tracker = ModalRouteTracker();
  ref.onDispose(tracker.dispose);
  return tracker;
}
