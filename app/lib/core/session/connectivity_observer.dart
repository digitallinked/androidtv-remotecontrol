import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Turns the platform's connectivity results into "the network changed"
/// events.
///
/// The first result is only a baseline (the plugin reports the current
/// network when listened to). After that, an event means the set of
/// connections differs from the previous one and includes something other
/// than `none`: going offline is not a reason to retry, coming back online
/// is.
class ConnectivityObserver {
  /// Starts listening to [source] straight away, so the baseline is the
  /// network at construction.
  ConnectivityObserver(Stream<List<ConnectivityResult>> source) {
    _subscription = source.listen(_onResults, onError: (Object _) {});
  }

  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  Set<ConnectivityResult>? _previous;
  int _events = 0;

  /// How many results the source delivered so far. Lets a caller tell
  /// whether one arrived while it was checking the network by hand.
  int get eventCount => _events;

  /// Emits whenever the phone switched to a network (a broadcast stream).
  /// Errors from the source are swallowed.
  Stream<void> get changes => _changes.stream;

  /// Replaces the baseline with [results] without emitting.
  ///
  /// iOS drops every connectivity event while the app is in the background,
  /// so the baseline goes stale; a later real change back to the old value
  /// would then look like a duplicate. Call this with a fresh reading when
  /// the app returns to the foreground.
  void resync(List<ConnectivityResult> results) => _previous = results.toSet();

  void _onResults(List<ConnectivityResult> results) {
    _events++;
    final current = results.toSet();
    final previous = _previous;
    _previous = current;
    if (previous == null || setEquals(previous, current)) return;
    if (current.every((r) => r == ConnectivityResult.none)) return;
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Stops listening and closes [changes].
  void dispose() {
    unawaited(_subscription.cancel());
    unawaited(_changes.close());
  }
}
