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

String _$activeTargetHash() => r'4ff4b78ff25bc3e2ac69c5a862e9d4e1aecf590f';

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

/// The session with the active TV, or `null` when no TV is saved.
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

/// The session with the active TV, or `null` when no TV is saved.
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
  /// The session with the active TV, or `null` when no TV is saved.
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

String _$remoteSessionHash() => r'7f673aface11226cea4c7bbaeb684f099e9af872';

/// The connection state of the active session; `disconnected` when there is
/// none.

@ProviderFor(connectionState)
final connectionStateProvider = ConnectionStateProvider._();

/// The connection state of the active session; `disconnected` when there is
/// none.

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
  ConnectionStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
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

String _$connectionStateHash() => r'00a8eae0f83c4c992d44ad53279bc8a73862c3af';

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
        retry: null,
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

String _$volumeHash() => r'7cd0c3b5adde04f6a7d1ec57a3f7750b290ceb7c';

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
        retry: null,
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

String _$powerStateHash() => r'aab4968713d12cf83885490fcd41ca887d188a67';

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
        retry: null,
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

String _$currentAppHash() => r'f28574a7247e7cad2ac371edb6b854ff19d976a2';
