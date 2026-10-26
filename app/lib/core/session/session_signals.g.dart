// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_signals.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The platform signals, for the whole app.

@ProviderFor(sessionSignals)
final sessionSignalsProvider = SessionSignalsProvider._();

/// The platform signals, for the whole app.

final class SessionSignalsProvider
    extends $FunctionalProvider<SessionSignals, SessionSignals, SessionSignals>
    with $Provider<SessionSignals> {
  /// The platform signals, for the whole app.
  SessionSignalsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionSignalsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionSignalsHash();

  @$internal
  @override
  $ProviderElement<SessionSignals> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SessionSignals create(Ref ref) {
    return sessionSignals(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionSignals value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionSignals>(value),
    );
  }
}

String _$sessionSignalsHash() => r'1c929280ca71b844ef0cf177ee352867fdd687a1';

/// The session timing: always [SessionTiming]'s defaults except in tests.

@ProviderFor(sessionTiming)
final sessionTimingProvider = SessionTimingProvider._();

/// The session timing: always [SessionTiming]'s defaults except in tests.

final class SessionTimingProvider
    extends $FunctionalProvider<SessionTiming, SessionTiming, SessionTiming>
    with $Provider<SessionTiming> {
  /// The session timing: always [SessionTiming]'s defaults except in tests.
  SessionTimingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionTimingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionTimingHash();

  @$internal
  @override
  $ProviderElement<SessionTiming> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SessionTiming create(Ref ref) {
    return sessionTiming(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionTiming value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionTiming>(value),
    );
  }
}

String _$sessionTimingHash() => r'2c722fd9741b49e33851714f722ed5cd49631533';
