import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/session/no_retry.dart';
import 'package:tv_remote/core/session/remote_client_factory.dart';
import 'package:tv_remote/core/session/remote_session.dart';
import 'package:tv_remote/core/session/session_signals.dart';
import 'package:tv_remote/core/session/session_supervisor.dart';
import 'package:tv_remote/core/session/session_target.dart';
import 'package:tv_remote/core/session/tv_remote_session.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/demo/demo_remote_session.dart';
import 'package:tv_remote/features/discovery/data/discovery_providers.dart';

export 'package:tv_remote/core/session/no_retry.dart';

part 'session_providers.g.dart';

/// Which TV the session follows: `null` (the default) means the most
/// recently connected saved TV.
@Riverpod(keepAlive: true)
class ActiveTarget extends _$ActiveTarget {
  @override
  SessionTarget? build() => null;

  /// Makes the saved TV [serviceName] the active one.
  ///
  /// The session is rebuilt even when that TV is already active: the TV may
  /// have just been paired again, and the old session holds the pin it was
  /// created with, so it would stay inert.
  void activateDevice(String serviceName) {
    state = DeviceTarget(serviceName);
    // Through the container: `ref.invalidate` refuses it, because the session
    // provider depends on this one.
    ref.container.invalidate(remoteSessionProvider);
  }

  /// Makes the simulated demo TV the active one.
  void startDemo() => state = const DemoTarget();

  /// Goes back to following the most recently connected TV.
  void clear() => state = null;
}

/// The session with the active TV, or `null` when no TV is saved. For
/// [DemoTarget] it is a [DemoRemoteSession].
///
/// It connects as soon as it is built and is disposed when it is rebuilt
/// (another TV, or [ActiveTarget.activateDevice]) or with the container. The
/// session's own state says whether commands can be sent, and that state lags
/// the connection by a microtask: callers still catch `NotConnectedException`.
///
/// An unusable client identity makes this provider fail (and, with
/// [noRetry], stay failed).
@Riverpod(keepAlive: true, retry: noRetry)
Future<RemoteSession?> remoteSession(Ref ref) async {
  final target = ref.watch(activeTargetProvider);
  final devices = ref.watch(deviceRepositoryProvider);
  final identityStore = ref.watch(identityStoreProvider);
  final clientFactory = ref.watch(remoteClientFactoryProvider);
  final resolveHost = ref.watch(hostResolverProvider);
  final signals = ref.watch(sessionSignalsProvider);
  final timing = ref.watch(sessionTimingProvider);

  if (target is DemoTarget) {
    return _startSession(ref, DemoRemoteSession(), timing, signals);
  }
  final device = switch (target) {
    DeviceTarget(:final serviceName) => await devices.find(serviceName),
    DemoTarget() => null, // Handled above.
    null => await devices.lastUsed(),
  };
  if (device == null || !ref.mounted) return null;

  final identity = await identityStore.loadOrCreate();
  // Rebuilt while the identity was loading: this result is discarded.
  if (!ref.mounted) return null;

  final session = TvRemoteSession(
    device: device,
    identity: identity,
    devices: devices,
    clientFactory: clientFactory,
    resolveHost: resolveHost,
  );
  return _startSession(ref, session, timing, signals);
}

/// Puts [session] under a supervisor, connects it, and ties both to [ref]'s
/// lifetime.
RemoteSession _startSession(
  Ref ref,
  RemoteSession session,
  SessionTiming timing,
  SessionSignals signals,
) {
  final supervisor = SessionSupervisor(
    session: session,
    signals: signals,
    backgroundGrace: timing.backgroundGrace,
    nudgeDebounce: timing.nudgeDebounce,
  );
  // Registered first, so the supervisor stops before the session closes.
  ref
    ..onDispose(supervisor.dispose)
    ..onDispose(session.dispose);
  unawaited(session.connect());
  return session;
}

/// The connection state of the active session; `disconnected` when there is
/// none.
///
/// If the session can't be built (for example, an unusable client identity)
/// this is an error, and it stays one: the providers below don't retry
/// either. `.future` of [remoteSessionProvider] rejects with the raw
/// exception, which Riverpod's default retry would re-run behind a loading
/// state. The UI treats `isLoading` or `isReloading` on these providers as
/// "not connected".
@Riverpod(retry: noRetry)
Stream<TvConnectionState> connectionState(Ref ref) async* {
  final session = await ref.watch(remoteSessionProvider.future);
  if (session == null) {
    yield const TvConnectionState(status: ConnectionStatus.disconnected);
    return;
  }
  yield* session.states;
}

/// The TV's volume: the last known value, then every change. `null` while
/// unknown or without a session.
@Riverpod(retry: noRetry)
Stream<VolumeChanged?> volume(Ref ref) async* {
  final session = await ref.watch(remoteSessionProvider.future);
  if (session == null) {
    yield null;
    return;
  }
  yield* _liveValue<VolumeChanged, VolumeChanged>(
    session,
    cached: session.volume,
    valueOf: (event) => event,
  );
}

/// Whether the TV's screen is on: the last known value, then every change.
/// `null` while unknown or without a session.
@Riverpod(retry: noRetry)
Stream<bool?> powerState(Ref ref) async* {
  final session = await ref.watch(remoteSessionProvider.future);
  if (session == null) {
    yield null;
    return;
  }
  yield* _liveValue<PowerStateChanged, bool>(
    session,
    cached: session.isPowerOn,
    valueOf: (event) => event.isOn,
  );
}

/// The package name of the TV's foreground app: the last known value, then
/// every change. `null` while unknown or without a session.
@Riverpod(retry: noRetry)
Stream<String?> currentApp(Ref ref) async* {
  final session = await ref.watch(remoteSessionProvider.future);
  if (session == null) {
    yield null;
    return;
  }
  yield* _liveValue<CurrentAppChanged, String>(
    session,
    cached: session.currentApp,
    valueOf: (event) => event.package,
  );
}

/// A live value of [session]: its cached value while connected, then the
/// value of every [E] event, and `null` whenever the session leaves
/// `connected`.
///
/// The session clears its own value when the connection ends, so this emits
/// `null` once per drop (not again while the status stays non-connected, and
/// not if the last emitted value was already `null`). It subscribes before it
/// emits the first value, so no event falls between the two.
Stream<V?> _liveValue<E extends RemoteEvent, V>(
  RemoteSession session, {
  required V? cached,
  required V Function(E event) valueOf,
}) => Stream<V?>.multi((listener) {
  V? last;
  void emit(V? value) {
    last = value;
    listener.add(value);
  }

  final eventSubscription = session.events.listen((event) {
    if (event is E) emit(valueOf(event));
  }, onDone: listener.close);
  // `states` replays the current state first, which is also what decides
  // whether `cached` is worth showing.
  final stateSubscription = session.states.listen((state) {
    if (state.status != ConnectionStatus.connected && last != null) {
      emit(null);
    }
  });
  emit(session.current.status == ConnectionStatus.connected ? cached : null);
  listener.onCancel = () => Future.wait([
    eventSubscription.cancel(),
    stateSubscription.cancel(),
  ]);
});
