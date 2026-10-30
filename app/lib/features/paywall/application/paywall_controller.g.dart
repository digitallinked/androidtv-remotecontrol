// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paywall_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The logic of the paywall opened from [source] (Ruling P6-R11).
///
/// Purchases and restores keep going when the screen is left: the answer is
/// still handed to [Premium] and counted.

@ProviderFor(PaywallController)
final paywallControllerProvider = PaywallControllerFamily._();

/// The logic of the paywall opened from [source] (Ruling P6-R11).
///
/// Purchases and restores keep going when the screen is left: the answer is
/// still handed to [Premium] and counted.
final class PaywallControllerProvider
    extends $NotifierProvider<PaywallController, PaywallState> {
  /// The logic of the paywall opened from [source] (Ruling P6-R11).
  ///
  /// Purchases and restores keep going when the screen is left: the answer is
  /// still handed to [Premium] and counted.
  PaywallControllerProvider._({
    required PaywallControllerFamily super.from,
    required PaywallSource super.argument,
  }) : super(
         retry: null,
         name: r'paywallControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$paywallControllerHash();

  @override
  String toString() {
    return r'paywallControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PaywallController create() => PaywallController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PaywallState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PaywallState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PaywallControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$paywallControllerHash() => r'0a61865621a386ecdaa737759189d0b9b48303e6';

/// The logic of the paywall opened from [source] (Ruling P6-R11).
///
/// Purchases and restores keep going when the screen is left: the answer is
/// still handed to [Premium] and counted.

final class PaywallControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          PaywallController,
          PaywallState,
          PaywallState,
          PaywallState,
          PaywallSource
        > {
  PaywallControllerFamily._()
    : super(
        retry: null,
        name: r'paywallControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The logic of the paywall opened from [source] (Ruling P6-R11).
  ///
  /// Purchases and restores keep going when the screen is left: the answer is
  /// still handed to [Premium] and counted.

  PaywallControllerProvider call(PaywallSource source) =>
      PaywallControllerProvider._(argument: source, from: this);

  @override
  String toString() => r'paywallControllerProvider';
}

/// The logic of the paywall opened from [source] (Ruling P6-R11).
///
/// Purchases and restores keep going when the screen is left: the answer is
/// still handed to [Premium] and counted.

abstract class _$PaywallController extends $Notifier<PaywallState> {
  late final _$args = ref.$arg as PaywallSource;
  PaywallSource get source => _$args;

  PaywallState build(PaywallSource source);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PaywallState, PaywallState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PaywallState, PaywallState>,
              PaywallState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
