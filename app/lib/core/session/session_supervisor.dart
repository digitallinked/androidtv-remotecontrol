import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:tv_remote/core/session/lifecycle_observer.dart';
import 'package:tv_remote/core/session/remote_session.dart';
import 'package:tv_remote/core/session/session_signals.dart';

/// Keeps a [RemoteSession] in step with the app lifecycle and the network.
///
/// - After `backgroundGrace` in the background the socket is closed; quick
///   app switches stay instant.
/// - Back in the foreground the connection is retried: reconnected from
///   scratch if it was closed (or the wall clock says the grace has passed,
///   because iOS suspends Dart timers), otherwise nudged.
/// - Network changes and the return to the foreground are coalesced: one
///   nudge per burst, `nudgeDebounce` after the last event.
/// - A supervisor created while the app is already in the background starts
///   as if it had just been backgrounded: the grace timer is running.
/// - Nothing is forwarded while the app is in the background. A session that
///   was `offline` stays offline through the grace disconnect, and nudging
///   it would open a socket behind the user's back.
class SessionSupervisor {
  /// Starts supervising `session`, listening to `signals`. `now` is the
  /// wall clock (a seam for tests).
  SessionSupervisor({
    required this._session,
    required SessionSignals signals,
    this._backgroundGrace = const Duration(seconds: 60),
    this._nudgeDebounce = const Duration(milliseconds: 500),
    this._now = DateTime.now,
  }) {
    _subscriptions = [
      signals.visibility.listen(_onVisibility),
      signals.networkChanges.listen((_) => _onNetworkChanged()),
    ];
    // The first visibility event may be a long way off (or never come while
    // the app stays backgrounded): start from where the app is now.
    if (signals.currentVisibility == AppVisibility.background) {
      _onVisibility(AppVisibility.background);
    }
  }

  final RemoteSession _session;
  final Duration _backgroundGrace;
  final Duration _nudgeDebounce;
  final DateTime Function() _now;

  late final List<StreamSubscription<void>> _subscriptions;
  Timer? _graceTimer;
  Timer? _nudgeTimer;
  bool _inBackground = false;
  DateTime? _backgroundSince;
  bool _closedInBackground = false;
  bool _networkChangedInBurst = false;
  bool _disposed = false;

  void _onVisibility(AppVisibility visibility) {
    if (_disposed) return;
    switch (visibility) {
      case AppVisibility.background:
        if (_inBackground) return;
        _inBackground = true;
        _backgroundSince = _now();
        _cancelNudge();
        _graceTimer?.cancel();
        _graceTimer = Timer(_backgroundGrace, _onGraceElapsed);
      case AppVisibility.foreground:
        if (!_inBackground) return;
        _inBackground = false;
        _graceTimer?.cancel();
        _graceTimer = null;
        _onReturned();
    }
  }

  void _onGraceElapsed() {
    _graceTimer = null;
    _closedInBackground = true;
    unawaited(_session.disconnect());
  }

  void _onReturned() {
    final since = _backgroundSince;
    final away = since == null ? Duration.zero : _now().difference(since);
    final mustReconnect = _closedInBackground || away >= _backgroundGrace;
    _closedInBackground = false;
    final needsPairing =
        _session.current.status == ConnectionStatus.needsPairing;
    if (mustReconnect && !needsPairing) {
      unawaited(_reconnect());
    } else {
      _scheduleNudge(network: false);
    }
  }

  Future<void> _reconnect() async {
    await _session.disconnect();
    if (_disposed) return;
    if (_inBackground) {
      // Backgrounded again before the reconnect: nothing is open, so the
      // next return must connect rather than nudge.
      _closedInBackground = true;
      return;
    }
    await _session.connect();
  }

  void _onNetworkChanged() {
    if (_disposed || _inBackground) return;
    _scheduleNudge(network: true);
  }

  void _scheduleNudge({required bool network}) {
    _networkChangedInBurst = _networkChangedInBurst || network;
    _nudgeTimer?.cancel();
    _nudgeTimer = Timer(_nudgeDebounce, _fireNudge);
  }

  void _fireNudge() {
    _nudgeTimer = null;
    final network = _networkChangedInBurst;
    _networkChangedInBurst = false;
    if (network) {
      _session.notifyNetworkChanged();
    } else {
      _session.notifyAppResumed();
    }
  }

  void _cancelNudge() {
    _nudgeTimer?.cancel();
    _nudgeTimer = null;
    _networkChangedInBurst = false;
  }

  /// Stops the timers and the subscriptions; later signals do nothing. Does
  /// not touch the session.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _graceTimer?.cancel();
    _cancelNudge();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel().catchError((Object _) {}));
    }
  }
}
