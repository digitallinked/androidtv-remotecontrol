// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pairing_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Pairs this phone with one TV while the pairing screen is open.
///
/// It owns the [PairingClient]; the client is closed on every way out
/// (leaving the screen, an error, the code expiring, success, a restart).
/// No error text is kept: the state carries only a [PairingErrorKind], so a
/// code or key can't reach the UI or a log.

@ProviderFor(PairingController)
final pairingControllerProvider = PairingControllerFamily._();

/// Pairs this phone with one TV while the pairing screen is open.
///
/// It owns the [PairingClient]; the client is closed on every way out
/// (leaving the screen, an error, the code expiring, success, a restart).
/// No error text is kept: the state carries only a [PairingErrorKind], so a
/// code or key can't reach the UI or a log.
final class PairingControllerProvider
    extends $NotifierProvider<PairingController, PairingState> {
  /// Pairs this phone with one TV while the pairing screen is open.
  ///
  /// It owns the [PairingClient]; the client is closed on every way out
  /// (leaving the screen, an error, the code expiring, success, a restart).
  /// No error text is kept: the state carries only a [PairingErrorKind], so a
  /// code or key can't reach the UI or a log.
  PairingControllerProvider._({
    required PairingControllerFamily super.from,
    required DiscoveredTv super.argument,
  }) : super(
         retry: null,
         name: r'pairingControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$pairingControllerHash();

  @override
  String toString() {
    return r'pairingControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PairingController create() => PairingController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PairingState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PairingState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PairingControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$pairingControllerHash() => r'0a0ec213ea098e156048e142d6e9b609e2ec0f84';

/// Pairs this phone with one TV while the pairing screen is open.
///
/// It owns the [PairingClient]; the client is closed on every way out
/// (leaving the screen, an error, the code expiring, success, a restart).
/// No error text is kept: the state carries only a [PairingErrorKind], so a
/// code or key can't reach the UI or a log.

final class PairingControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          PairingController,
          PairingState,
          PairingState,
          PairingState,
          DiscoveredTv
        > {
  PairingControllerFamily._()
    : super(
        retry: null,
        name: r'pairingControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Pairs this phone with one TV while the pairing screen is open.
  ///
  /// It owns the [PairingClient]; the client is closed on every way out
  /// (leaving the screen, an error, the code expiring, success, a restart).
  /// No error text is kept: the state carries only a [PairingErrorKind], so a
  /// code or key can't reach the UI or a log.

  PairingControllerProvider call(DiscoveredTv tv) =>
      PairingControllerProvider._(argument: tv, from: this);

  @override
  String toString() => r'pairingControllerProvider';
}

/// Pairs this phone with one TV while the pairing screen is open.
///
/// It owns the [PairingClient]; the client is closed on every way out
/// (leaving the screen, an error, the code expiring, success, a restart).
/// No error text is kept: the state carries only a [PairingErrorKind], so a
/// code or key can't reach the UI or a log.

abstract class _$PairingController extends $Notifier<PairingState> {
  late final _$args = ref.$arg as DiscoveredTv;
  DiscoveredTv get tv => _$args;

  PairingState build(DiscoveredTv tv);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PairingState, PairingState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PairingState, PairingState>,
              PairingState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
