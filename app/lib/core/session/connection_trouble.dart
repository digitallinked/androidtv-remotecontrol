import 'package:atv_remote/atv_remote.dart';
import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/session/not_connected_notices.dart';
import 'package:tv_remote/core/session/session_providers.dart';

part 'connection_trouble.g.dart';

/// The statuses that mean the connection is in trouble: lost, refused or
/// unreachable.
const Set<ConnectionStatus> _troubled = {
  ConnectionStatus.reconnecting,
  ConnectionStatus.needsPairing,
  ConnectionStatus.offline,
};

/// When the connection last had trouble (Rulings P8-R12, P8-C9), or `null`
/// if it hasn't since the app started.
///
/// Trouble is:
/// - every `reconnecting`, `offline` or `needsPairing` state (a lost
///   connection, a first connect that failed, each reconnect attempt);
/// - a session that could not be opened (the connection state is an error);
/// - a "Not connected" notice.
///
/// Trouble lasts until it ends: while the connection is `reconnecting` the
/// trouble is going on, so [troubleWithin] is true, and leaving
/// `reconnecting` (the app closing it, a TV switch, a recovery) is noted as
/// its end. `offline` and `needsPairing` are the connection having stopped
/// trying: they are noted when they arrive and then age like a notice, so a
/// TV left offline doesn't hold back the ads and the review prompt forever.
/// The app's own disconnects from `connected` are not trouble.
///
/// Interstitial pacing and the review prompt ask [troubleWithin]. They keep
/// this listened to from launch, so it hears the trouble that happens before
/// they ask: Riverpod may pause the listeners inside a provider that nothing
/// listens to. A status already in trouble when this is built counts.
@Riverpod(keepAlive: true)
class ConnectionTrouble extends _$ConnectionTrouble {
  ConnectionStatus? _last;

  // While `build` runs, a status already in trouble is noted here and
  // returned: state set during `build` would be replaced by its result.
  bool _building = false;
  DateTime? _builtWith;

  /// Whether the connection is reconnecting right now.
  bool get _ongoing => _last == ConnectionStatus.reconnecting;

  @override
  DateTime? build() {
    _last = null;
    _building = true;
    _builtWith = null;
    ref
      // The session going away ends its trouble; its status says nothing
      // about the new one.
      ..listen(remoteSessionProvider, (_, _) => _move(null))
      ..listen(connectionStateProvider, (_, next) {
        if (next.isLoading) return;
        if (next.hasError) {
          _move(null);
          note();
          return;
        }
        final status = next.value?.status;
        if (status != null) _move(status);
      }, fireImmediately: true)
      ..listen(notConnectedNoticesProvider, (_, _) => note());
    _building = false;
    return _builtWith;
  }

  /// Moves to [status], noting trouble as it arrives and as it ends.
  void _move(ConnectionStatus? status) {
    final wasOngoing = _ongoing;
    _last = status;
    if (_troubled.contains(status) || (wasOngoing && !_ongoing)) note();
  }

  /// Records trouble now.
  void note() {
    if (_building) {
      _builtWith = clock.now();
    } else {
      state = clock.now();
    }
  }

  /// Whether there is trouble now (the connection is reconnecting) or there
  /// was some less than [window] ago.
  bool troubleWithin(Duration window) {
    if (_ongoing) return true;
    final last = state;
    return last != null && clock.now().difference(last) < window;
  }
}
