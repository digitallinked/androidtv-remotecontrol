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
  LifecycleObserver({WidgetsBinding? binding}) {
    _listener = AppLifecycleListener(
      binding: binding,
      onStateChange: _onStateChange,
    );
  }

  late final AppLifecycleListener _listener;
  final StreamController<AppVisibility> _changes =
      StreamController<AppVisibility>.broadcast();
  bool _inBackground = false;

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
    unawaited(_changes.close());
  }
}
