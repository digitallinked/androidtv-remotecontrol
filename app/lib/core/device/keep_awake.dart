import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/device/screen_services.dart';

/// Keeps the screen on while its [child] is the top page (Ruling P4-R14).
///
/// The wake lock is held while [enabled], no other page covers this one, and
/// the app is in the foreground. A sheet or dialog over the page does not
/// count as covering it. It is released the moment any of that stops being
/// true, and when this widget goes away.
///
/// The covering is reported by the `RouteObserver` registered on the router
/// ([pageRouteObserverProvider]); without a route (or an observer on the
/// navigator) the page is never "covered".
class KeepAwake extends ConsumerStatefulWidget {
  /// Creates the wake-lock scope.
  const KeepAwake({required this.enabled, required this.child, super.key});

  /// Whether the user wants the screen kept on (the setting).
  final bool enabled;

  /// The page content.
  final Widget child;

  @override
  ConsumerState<KeepAwake> createState() => _KeepAwakeState();
}

class _KeepAwakeState extends ConsumerState<KeepAwake> with RouteAware {
  late final ScreenWakeLock _lock = ref.read(screenWakeLockProvider);
  late final RouteObserver<PageRoute<dynamic>> _observer = ref.read(
    pageRouteObserverProvider,
  );
  late final AppLifecycleListener _lifecycle;

  PageRoute<dynamic>? _route;
  bool _covered = false;
  bool _foreground = true;

  /// What the wake lock was last told.
  bool _held = false;

  @override
  void initState() {
    super.initState();
    _foreground = _isForeground(WidgetsBinding.instance.lifecycleState);
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        _foreground = _isForeground(state);
        _sync();
      },
    );
  }

  /// `inactive` (a system dialog, the notification shade) is still on screen.
  static bool _isForeground(AppLifecycleState? state) =>
      state == null ||
      state == AppLifecycleState.resumed ||
      state == AppLifecycleState.inactive;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    final pageRoute = route is PageRoute<dynamic> ? route : null;
    if (!identical(pageRoute, _route)) {
      _observer.unsubscribe(this);
      _route = pageRoute;
      _covered = false;
      if (pageRoute != null) _observer.subscribe(this, pageRoute);
    }
    _sync();
  }

  @override
  void didUpdateWidget(KeepAwake oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void didPushNext() {
    _covered = true;
    _sync();
  }

  @override
  void didPopNext() {
    _covered = false;
    _sync();
  }

  /// Tells the wake lock about a change, and only about a change.
  void _sync() {
    final want = widget.enabled && !_covered && _foreground;
    if (want == _held) return;
    _held = want;
    unawaited(want ? _lock.enable() : _lock.disable());
  }

  @override
  void dispose() {
    _observer.unsubscribe(this);
    _lifecycle.dispose();
    if (_held) {
      _held = false;
      unawaited(_lock.disable());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
