import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/session/remote_client_factory.dart';
import 'package:tv_remote/core/session/remote_session.dart';
import 'package:tv_remote/core/session/session_target.dart';
import 'package:tv_remote/core/session/tv_remote_session.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/discovery/data/discovery_providers.dart';

part 'session_providers.g.dart';

/// A retry policy that never retries.
///
/// Riverpod 3 retries a failed provider by default, which would hide the
/// error behind a loading state. Providers whose failure the UI must show
/// (and the user must be able to retry by hand) use this.
Duration? noRetry(int retryCount, Object error) => null;

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

  /// Goes back to following the most recently connected TV.
  void clear() => state = null;
}

/// The session with the active TV, or `null` when no TV is saved.
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

  final device = switch (target) {
    DeviceTarget(:final serviceName) => await devices.find(serviceName),
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
  ref.onDispose(session.dispose);
  unawaited(session.connect());
  return session;
}

/// The connection state of the active session; `disconnected` when there is
/// none.
@riverpod
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
@riverpod
Stream<VolumeChanged?> volume(Ref ref) async* {
  final session = await ref.watch(remoteSessionProvider.future);
  if (session == null) {
    yield null;
    return;
  }
  yield* _cachedThenEvents<VolumeChanged, VolumeChanged>(
    session,
    cached: session.volume,
    valueOf: (event) => event,
  );
}

/// Whether the TV's screen is on: the last known value, then every change.
/// `null` while unknown or without a session.
@riverpod
Stream<bool?> powerState(Ref ref) async* {
  final session = await ref.watch(remoteSessionProvider.future);
  if (session == null) {
    yield null;
    return;
  }
  yield* _cachedThenEvents<PowerStateChanged, bool>(
    session,
    cached: session.isPowerOn,
    valueOf: (event) => event.isOn,
  );
}

/// The package name of the TV's foreground app: the last known value, then
/// every change. `null` while unknown or without a session.
@riverpod
Stream<String?> currentApp(Ref ref) async* {
  final session = await ref.watch(remoteSessionProvider.future);
  if (session == null) {
    yield null;
    return;
  }
  yield* _cachedThenEvents<CurrentAppChanged, String>(
    session,
    cached: session.currentApp,
    valueOf: (event) => event.package,
  );
}

/// Emits [cached], then the value of every [E] event of [session].
///
/// It subscribes before it emits [cached], so no event falls between the
/// two.
Stream<V?> _cachedThenEvents<E extends RemoteEvent, V>(
  RemoteSession session, {
  required V? cached,
  required V Function(E event) valueOf,
}) => Stream<V?>.multi((listener) {
  final subscription = session.events.listen(
    (event) {
      if (event is E) listener.add(valueOf(event));
    },
    onDone: listener.close,
  );
  listener
    ..add(cached)
    ..onCancel = subscription.cancel;
});
