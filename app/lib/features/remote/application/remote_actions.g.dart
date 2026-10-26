// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'remote_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Where sent commands are reported. A no-op until Phase 6 attaches analytics
/// and the review prompter's press counter.

@ProviderFor(remoteActionListener)
final remoteActionListenerProvider = RemoteActionListenerProvider._();

/// Where sent commands are reported. A no-op until Phase 6 attaches analytics
/// and the review prompter's press counter.

final class RemoteActionListenerProvider
    extends
        $FunctionalProvider<
          RemoteActionListener,
          RemoteActionListener,
          RemoteActionListener
        >
    with $Provider<RemoteActionListener> {
  /// Where sent commands are reported. A no-op until Phase 6 attaches analytics
  /// and the review prompter's press counter.
  RemoteActionListenerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'remoteActionListenerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$remoteActionListenerHash();

  @$internal
  @override
  $ProviderElement<RemoteActionListener> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RemoteActionListener create(Ref ref) {
    return remoteActionListener(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RemoteActionListener value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RemoteActionListener>(value),
    );
  }
}

String _$remoteActionListenerHash() =>
    r'f019182a81525fb3dd37557362ca2c928db6e161';

/// Counts the presses that were refused because the TV isn't connected; the
/// remote screen shows the "Not connected" snackbar for each bump.

@ProviderFor(NotConnectedNotices)
final notConnectedNoticesProvider = NotConnectedNoticesProvider._();

/// Counts the presses that were refused because the TV isn't connected; the
/// remote screen shows the "Not connected" snackbar for each bump.
final class NotConnectedNoticesProvider
    extends $NotifierProvider<NotConnectedNotices, int> {
  /// Counts the presses that were refused because the TV isn't connected; the
  /// remote screen shows the "Not connected" snackbar for each bump.
  NotConnectedNoticesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notConnectedNoticesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notConnectedNoticesHash();

  @$internal
  @override
  NotConnectedNotices create() => NotConnectedNotices();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$notConnectedNoticesHash() =>
    r'1b134254f600c54dc20b75a140ab41930396c085';

/// Counts the presses that were refused because the TV isn't connected; the
/// remote screen shows the "Not connected" snackbar for each bump.

abstract class _$NotConnectedNotices extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The [RemoteActions] for the active TV and the current settings.
///
/// This provider is autoDispose: callers must watch it to keep it alive. A
/// disposed instance refuses silently (returns `false`, no notice), so code
/// that holds an instance across an async gap must use the return value.
///
/// Rebuilt when the session, Smooth Press or haptics change; the old instance
/// is disposed, which releases an active hold, so a settings change or a TV
/// switch in the middle of a hold never leaves a key stuck.

@ProviderFor(remoteActions)
final remoteActionsProvider = RemoteActionsProvider._();

/// The [RemoteActions] for the active TV and the current settings.
///
/// This provider is autoDispose: callers must watch it to keep it alive. A
/// disposed instance refuses silently (returns `false`, no notice), so code
/// that holds an instance across an async gap must use the return value.
///
/// Rebuilt when the session, Smooth Press or haptics change; the old instance
/// is disposed, which releases an active hold, so a settings change or a TV
/// switch in the middle of a hold never leaves a key stuck.

final class RemoteActionsProvider
    extends $FunctionalProvider<RemoteActions, RemoteActions, RemoteActions>
    with $Provider<RemoteActions> {
  /// The [RemoteActions] for the active TV and the current settings.
  ///
  /// This provider is autoDispose: callers must watch it to keep it alive. A
  /// disposed instance refuses silently (returns `false`, no notice), so code
  /// that holds an instance across an async gap must use the return value.
  ///
  /// Rebuilt when the session, Smooth Press or haptics change; the old instance
  /// is disposed, which releases an active hold, so a settings change or a TV
  /// switch in the middle of a hold never leaves a key stuck.
  RemoteActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'remoteActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$remoteActionsHash();

  @$internal
  @override
  $ProviderElement<RemoteActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RemoteActions create(Ref ref) {
    return remoteActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RemoteActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RemoteActions>(value),
    );
  }
}

String _$remoteActionsHash() => r'8c8e15688068fd78b485224752a06956d10ebdf2';
