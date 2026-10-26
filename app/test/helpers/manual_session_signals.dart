import 'dart:async';

import 'package:tv_remote/core/session/lifecycle_observer.dart';
import 'package:tv_remote/core/session/session_signals.dart';

/// [SessionSignals] that tests fire by hand. Delivery is synchronous.
class ManualSessionSignals implements SessionSignals {
  final StreamController<AppVisibility> _visibility =
      StreamController<AppVisibility>.broadcast(sync: true);
  final StreamController<void> _network = StreamController<void>.broadcast(
    sync: true,
  );

  /// Delivers [AppVisibility.background].
  void background() => _visibility.add(AppVisibility.background);

  /// Delivers [AppVisibility.foreground].
  void foreground() => _visibility.add(AppVisibility.foreground);

  /// Delivers a network change.
  void networkChanged() => _network.add(null);

  @override
  Stream<AppVisibility> get visibility => _visibility.stream;

  @override
  Stream<void> get networkChanges => _network.stream;
}
