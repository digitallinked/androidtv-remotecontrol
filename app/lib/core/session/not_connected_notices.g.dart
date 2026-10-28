// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'not_connected_notices.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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
