// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_trouble.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(ConnectionTrouble)
final connectionTroubleProvider = ConnectionTroubleProvider._();

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
final class ConnectionTroubleProvider
    extends $NotifierProvider<ConnectionTrouble, DateTime?> {
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
  ConnectionTroubleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectionTroubleProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectionTroubleHash();

  @$internal
  @override
  ConnectionTrouble create() => ConnectionTrouble();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime?>(value),
    );
  }
}

String _$connectionTroubleHash() => r'692fc4fa339fe534068c66062600540fdbd5cc54';

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

abstract class _$ConnectionTrouble extends $Notifier<DateTime?> {
  DateTime? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DateTime?, DateTime?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DateTime?, DateTime?>,
              DateTime?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
