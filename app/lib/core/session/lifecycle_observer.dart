import 'dart:async';

import 'package:flutter/widgets.dart';

/// Whether the app is on screen.
enum AppVisibility {
  /// The app is in use again after a spell in the background.
  foreground,

  /// The app is no longer visible (hidden or paused).
  background,
}

/// Turns the platform lifecycle into [AppVisibility] changes.
///
/// `inactive` alone (a system dialog, the app switcher peek, an incoming
/// call banner) changes nothing: the app is still visible.
class LifecycleObserver {
  /// Starts listening on [binding] (the app's `WidgetsBinding` by default).
  ///
  /// It starts from the binding's current lifecycle state, so an observer
  /// created while the app is in the background reports [current] as
  /// [AppVisibility.background] and emits [AppVisibility.foreground] on the
  /// next `resumed`.
  LifecycleObserver({WidgetsBinding? binding}) {
    final lifecycleState = (binding ?? WidgetsBinding.instance).lifecycleState;
    _inBackground =
        lifecycleState == AppLifecycleState.hidden ||
        lifecycleState == AppLifecycleState.paused;
    _listener = AppLifecycleListener(
      binding: binding,
      onStateChange: _onStateChange,
    );
  }

  late final AppLifecycleListener _listener;
  final StreamController<AppVisibility> _changes =
      StreamController<AppVisibility>.broadcast();
  bool _inBackground = false;

  /// The visibility right now: [AppVisibility.background] after `hidden` or
  /// `paused` until `resumed`, otherwise [AppVisibility.foreground].
  AppVisibility get current =>
      _inBackground ? AppVisibility.background : AppVisibility.foreground;

  /// Emits [AppVisibility.background] on the first transition to `hidden` or
  /// `paused`, and [AppVisibility.foreground] on `resumed` after a
  /// background. A broadcast stream.
  Stream<AppVisibility> get changes => _changes.stream;

  void _onStateChange(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        if (_inBackground) return;
        _inBackground = true;
        _emit(AppVisibility.background);
      case AppLifecycleState.resumed:
        if (!_inBackground) return;
        _inBackground = false;
        _emit(AppVisibility.foreground);
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  void _emit(AppVisibility visibility) {
    if (!_changes.isClosed) _changes.add(visibility);
  }

  /// Stops listening and closes [changes].
  void dispose() {
    _listener.dispose();
    unawaited(_changes.close().catchError((Object _) {}));
  }
}
