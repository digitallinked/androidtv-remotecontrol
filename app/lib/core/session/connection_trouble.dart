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

/// When the connection last had trouble (Ruling P8-R12), or `null` if it
/// hasn't since the app started.
///
/// Trouble is:
/// - entering `reconnecting`, `offline` or `needsPairing` from another
///   status (a lost connection, or a first connect that failed);
/// - a session that could not be opened (the connection state is an error);
/// - a "Not connected" notice.
///
/// The app's own disconnects (`disconnected`) are not trouble, and staying in
/// trouble (another reconnect attempt) keeps the time it started.
///
/// Interstitial pacing and the review prompt ask [troubleWithin]. They keep
/// this listened to from launch, so it hears the trouble that happens before
/// they ask: Riverpod may pause the listeners inside a provider that nothing
/// listens to.
@Riverpod(keepAlive: true)
class ConnectionTrouble extends _$ConnectionTrouble {
  ConnectionStatus? _last;

  @override
  DateTime? build() {
    _last = null;
    ref
      // A status of the session that is going away says nothing about the
      // new one.
      ..listen(remoteSessionProvider, (_, _) => _last = null)
      ..listen(connectionStateProvider, (_, next) {
        if (next.isLoading) return;
        if (next.hasError) {
          _last = null;
          note();
          return;
        }
        final status = next.value?.status;
        if (status == null) return;
        final was = _last;
        _last = status;
        if (_troubled.contains(status) && status != was) note();
      })
      ..listen(notConnectedNoticesProvider, (_, _) => note());
    return null;
  }

  /// Records trouble now.
  void note() => state = clock.now();

  /// Whether there was trouble less than [window] ago.
  bool troubleWithin(Duration window) {
    final last = state;
    return last != null && clock.now().difference(last) < window;
  }
}
