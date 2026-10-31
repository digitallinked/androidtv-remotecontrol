// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_trouble.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(ConnectionTrouble)
final connectionTroubleProvider = ConnectionTroubleProvider._();

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
final class ConnectionTroubleProvider
    extends $NotifierProvider<ConnectionTrouble, DateTime?> {
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

String _$connectionTroubleHash() => r'eca68feb4cafa3d1fe5bb9c203496aa015107579';

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
