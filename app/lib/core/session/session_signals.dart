import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/session/connectivity_observer.dart';
import 'package:tv_remote/core/session/lifecycle_observer.dart';

part 'session_signals.g.dart';

/// What the session supervisor listens to: whether the app is on screen and
/// whether the phone's network changed. Tests replace it with a manual one.
abstract interface class SessionSignals {
  /// The app going to the background and coming back.
  Stream<AppVisibility> get visibility;

  /// The phone switching to another (connected) network.
  Stream<void> get networkChanges;
}

/// [SessionSignals] from the platform: the app lifecycle and
/// `connectivity_plus`.
class PlatformSessionSignals implements SessionSignals {
  /// Creates the signals; [lifecycle] and [connectivity] default to the real
  /// platform ones.
  PlatformSessionSignals({
    LifecycleObserver? lifecycle,
    ConnectivityObserver? connectivity,
  }) : _lifecycle = lifecycle ?? LifecycleObserver(),
       _connectivity =
           connectivity ??
           ConnectivityObserver(Connectivity().onConnectivityChanged);

  final LifecycleObserver _lifecycle;
  final ConnectivityObserver _connectivity;

  @override
  Stream<AppVisibility> get visibility => _lifecycle.changes;

  @override
  Stream<void> get networkChanges => _connectivity.changes;

  /// Stops both observers.
  void dispose() {
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
