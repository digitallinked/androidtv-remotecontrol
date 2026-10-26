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

  /// Emits whenever the phone switched to a network (a broadcast stream).
  /// Errors from the source are swallowed.
  Stream<void> get changes => _changes.stream;

  void _onResults(List<ConnectivityResult> results) {
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
