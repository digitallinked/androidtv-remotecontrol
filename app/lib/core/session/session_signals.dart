import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/session/connectivity_observer.dart';
import 'package:tv_remote/core/session/lifecycle_observer.dart';

part 'session_signals.g.dart';

/// What the session supervisor listens to: whether the app is on screen and
/// whether the phone's network changed. Tests replace it with a manual one.
abstract interface class SessionSignals {
  /// The visibility right now, for a supervisor created mid-flight.
  AppVisibility get currentVisibility;

  /// The app going to the background and coming back.
  Stream<AppVisibility> get visibility;

  /// The phone switching to another (connected) network.
  Stream<void> get networkChanges;
}

/// Reads the phone's current connectivity once.
typedef ConnectivityChecker = Future<List<ConnectivityResult>> Function();

/// [SessionSignals] from the platform: the app lifecycle and
/// `connectivity_plus`.
///
/// Each return to the foreground re-baselines the connectivity observer with
/// a fresh reading, because iOS drops connectivity events while the app is in
/// the background.
class PlatformSessionSignals implements SessionSignals {
  /// Creates the signals; [lifecycle], [connectivity] and [checkConnectivity]
  /// default to the real platform ones.
  PlatformSessionSignals({
    LifecycleObserver? lifecycle,
    ConnectivityObserver? connectivity,
    ConnectivityChecker? checkConnectivity,
  }) : _lifecycle = lifecycle ?? LifecycleObserver(),
       _connectivity =
           connectivity ??
           ConnectivityObserver(Connectivity().onConnectivityChanged),
       _check = checkConnectivity ?? Connectivity().checkConnectivity {
    _foregroundSubscription = _lifecycle.changes
        .where((v) => v == AppVisibility.foreground)
        .listen((_) => unawaited(_resync()));
  }

  final LifecycleObserver _lifecycle;
  final ConnectivityObserver _connectivity;
  final ConnectivityChecker _check;
  late final StreamSubscription<AppVisibility> _foregroundSubscription;
  bool _disposed = false;

  Future<void> _resync() async {
    final seen = _connectivity.eventCount;
    try {
      final results = await _check();
      // A live event that arrived meanwhile is newer than this reading.
      if (_disposed || _connectivity.eventCount != seen) return;
      _connectivity.resync(results);
    } on Object {
      // Keep the old baseline; the next event corrects it.
    }
  }

  @override
  AppVisibility get currentVisibility => _lifecycle.current;

  @override
  Stream<AppVisibility> get visibility => _lifecycle.changes;

  @override
  Stream<void> get networkChanges => _connectivity.changes;

  /// Stops both observers.
  void dispose() {
    _disposed = true;
    unawaited(_foregroundSubscription.cancel());
    _lifecycle.dispose();
    _connectivity.dispose();
  }
}

/// The platform signals, for the whole app.
@Riverpod(keepAlive: true)
SessionSignals sessionSignals(Ref ref) {
  final signals = PlatformSessionSignals();
  ref.onDispose(signals.dispose);
  return signals;
}

/// How long the session waits before reacting to the app lifecycle.
///
/// A test seam: production always uses the defaults (Ruling 9).
@immutable
class SessionTiming {
  /// Creates a timing; the defaults are the production values.
  const SessionTiming({
    this.backgroundGrace = const Duration(seconds: 60),
    this.nudgeDebounce = const Duration(milliseconds: 500),
  });

  /// How long the app may stay in the background before the socket closes.
  final Duration backgroundGrace;

  /// How long resume and network nudges are collected into one.
  final Duration nudgeDebounce;
}

/// The session timing: always [SessionTiming]'s defaults except in tests.
@Riverpod(keepAlive: true)
SessionTiming sessionTiming(Ref ref) => const SessionTiming();
