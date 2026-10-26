import 'dart:async';

import 'package:tv_remote/core/session/lifecycle_observer.dart';
import 'package:tv_remote/core/session/session_signals.dart';

/// [SessionSignals] that tests fire by hand. Delivery is synchronous.
class ManualSessionSignals implements SessionSignals {
  /// Creates signals for an app that is [initial] on screen.
  ManualSessionSignals({AppVisibility initial = AppVisibility.foreground})
    : currentVisibility = initial;

  final StreamController<AppVisibility> _visibility =
      StreamController<AppVisibility>.broadcast(sync: true);
  final StreamController<void> _network = StreamController<void>.broadcast(
    sync: true,
  );

  /// How many listeners [visibility] has right now.
  int visibilityListeners = 0;

  /// How many listeners [networkChanges] has right now.
  int networkListeners = 0;

  @override
  AppVisibility currentVisibility;

  /// Delivers [AppVisibility.background].
  void background() {
    currentVisibility = AppVisibility.background;
    _visibility.add(AppVisibility.background);
  }

  /// Delivers [AppVisibility.foreground].
  void foreground() {
    currentVisibility = AppVisibility.foreground;
    _visibility.add(AppVisibility.foreground);
  }

  /// Delivers a network change.
  void networkChanged() => _network.add(null);

  @override
  Stream<AppVisibility> get visibility =>
      _counted(_visibility.stream, (delta) => visibilityListeners += delta);

  @override
  Stream<void> get networkChanges =>
      _counted(_network.stream, (delta) => networkListeners += delta);

  Stream<T> _counted<T>(Stream<T> source, void Function(int delta) count) =>
      Stream<T>.multi((listener) {
        count(1);
        final subscription = source.listen(
          listener.addSync,
          onError: listener.addErrorSync,
          onDone: listener.closeSync,
        );
        listener.onCancel = () {
          count(-1);
          return subscription.cancel();
        };
      }, isBroadcast: true);
}
