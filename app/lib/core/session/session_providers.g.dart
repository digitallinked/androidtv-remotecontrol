// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Which TV the session follows: `null` (the default) means the most
/// recently connected saved TV.

@ProviderFor(ActiveTarget)
final activeTargetProvider = ActiveTargetProvider._();

/// Which TV the session follows: `null` (the default) means the most
/// recently connected saved TV.
final class ActiveTargetProvider
    extends $NotifierProvider<ActiveTarget, SessionTarget?> {
  /// Which TV the session follows: `null` (the default) means the most
  /// recently connected saved TV.
  ActiveTargetProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeTargetProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeTargetHash();

  @$internal
  @override
  ActiveTarget create() => ActiveTarget();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionTarget? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionTarget?>(value),
    );
  }
}

String _$activeTargetHash() => r'df026daabff8b6698aacfe8bce0a23cd9260dc8d';

/// Which TV the session follows: `null` (the default) means the most
/// recently connected saved TV.

abstract class _$ActiveTarget extends $Notifier<SessionTarget?> {
  SessionTarget? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SessionTarget?, SessionTarget?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SessionTarget?, SessionTarget?>,
              SessionTarget?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
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

@ProviderFor(remoteSession)
final remoteSessionProvider = RemoteSessionProvider._();

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

final class RemoteSessionProvider
    extends
        $FunctionalProvider<
          AsyncValue<RemoteSession?>,
          RemoteSession?,
          FutureOr<RemoteSession?>
        >
    with $FutureModifier<RemoteSession?>, $FutureProvider<RemoteSession?> {
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
  RemoteSessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'remoteSessionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$remoteSessionHash();

  @$internal
  @override
  $FutureProviderElement<RemoteSession?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<RemoteSession?> create(Ref ref) {
    return remoteSession(ref);
  }
}

String _$remoteSessionHash() => r'8e954c822b68a529afc649d44143f316885737ef';

/// The connection state of the active session; `disconnected` when there is
/// none.
///
/// If the session can't be built (for example, an unusable client identity)
/// this is an error, and it stays one: the providers below don't retry
/// either. `.future` of [remoteSessionProvider] rejects with the raw
/// exception, which Riverpod's default retry would re-run behind a loading
/// state. The UI treats `isLoading` or `isReloading` on these providers as
/// "not connected".

@ProviderFor(connectionState)
final connectionStateProvider = ConnectionStateProvider._();

/// The connection state of the active session; `disconnected` when there is
/// none.
///
/// If the session can't be built (for example, an unusable client identity)
/// this is an error, and it stays one: the providers below don't retry
/// either. `.future` of [remoteSessionProvider] rejects with the raw
/// exception, which Riverpod's default retry would re-run behind a loading
/// state. The UI treats `isLoading` or `isReloading` on these providers as
/// "not connected".

final class ConnectionStateProvider
    extends
        $FunctionalProvider<
          AsyncValue<TvConnectionState>,
          TvConnectionState,
          Stream<TvConnectionState>
        >
    with
        $FutureModifier<TvConnectionState>,
        $StreamProvider<TvConnectionState> {
  /// The connection state of the active session; `disconnected` when there is
  /// none.
  ///
  /// If the session can't be built (for example, an unusable client identity)
  /// this is an error, and it stays one: the providers below don't retry
  /// either. `.future` of [remoteSessionProvider] rejects with the raw
  /// exception, which Riverpod's default retry would re-run behind a loading
  /// state. The UI treats `isLoading` or `isReloading` on these providers as
  /// "not connected".
  ConnectionStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'connectionStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectionStateHash();

  @$internal
  @override
  $StreamProviderElement<TvConnectionState> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<TvConnectionState> create(Ref ref) {
    return connectionState(ref);
  }
}

String _$connectionStateHash() => r'4bcb75bf7d09473cefeef58b704fc36b808432d4';

/// The TV's volume: the last known value, then every change. `null` while
/// unknown or without a session.

@ProviderFor(volume)
final volumeProvider = VolumeProvider._();

/// The TV's volume: the last known value, then every change. `null` while
/// unknown or without a session.

final class VolumeProvider
    extends
        $FunctionalProvider<
          AsyncValue<VolumeChanged?>,
          VolumeChanged?,
          Stream<VolumeChanged?>
        >
    with $FutureModifier<VolumeChanged?>, $StreamProvider<VolumeChanged?> {
  /// The TV's volume: the last known value, then every change. `null` while
  /// unknown or without a session.
  VolumeProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'volumeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$volumeHash();

  @$internal
  @override
  $StreamProviderElement<VolumeChanged?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<VolumeChanged?> create(Ref ref) {
    return volume(ref);
  }
}

String _$volumeHash() => r'5651ee189848641a8e56c496e9b08a70041716f8';

/// Whether the TV's screen is on: the last known value, then every change.
/// `null` while unknown or without a session.

@ProviderFor(powerState)
final powerStateProvider = PowerStateProvider._();

/// Whether the TV's screen is on: the last known value, then every change.
/// `null` while unknown or without a session.

final class PowerStateProvider
    extends $FunctionalProvider<AsyncValue<bool?>, bool?, Stream<bool?>>
    with $FutureModifier<bool?>, $StreamProvider<bool?> {
  /// Whether the TV's screen is on: the last known value, then every change.
  /// `null` while unknown or without a session.
  PowerStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'powerStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$powerStateHash();

  @$internal
  @override
  $StreamProviderElement<bool?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool?> create(Ref ref) {
    return powerState(ref);
  }
}

String _$powerStateHash() => r'a9a66c8b436f4c6b897471441d722742ff41481e';

/// The package name of the TV's foreground app: the last known value, then
/// every change. `null` while unknown or without a session.

@ProviderFor(currentApp)
final currentAppProvider = CurrentAppProvider._();

/// The package name of the TV's foreground app: the last known value, then
/// every change. `null` while unknown or without a session.

final class CurrentAppProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, Stream<String?>>
    with $FutureModifier<String?>, $StreamProvider<String?> {
  /// The package name of the TV's foreground app: the last known value, then
  /// every change. `null` while unknown or without a session.
  CurrentAppProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'currentAppProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentAppHash();

  @$internal
  @override
  $StreamProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<String?> create(Ref ref) {
    return currentApp(ref);
  }
}

String _$currentAppHash() => r'f2167a9c91911120d8811ac6656404d50d9aff9b';
