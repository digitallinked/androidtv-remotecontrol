// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'premium.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The user's Premium state.
///
/// This is a stub that is always free. Task 6.7 replaces the body of
/// [build] with the real entitlement and keeps this name and [PremiumState].

@ProviderFor(Premium)
final premiumProvider = PremiumProvider._();

/// The user's Premium state.
///
/// This is a stub that is always free. Task 6.7 replaces the body of
/// [build] with the real entitlement and keeps this name and [PremiumState].
final class PremiumProvider extends $NotifierProvider<Premium, PremiumState> {
  /// The user's Premium state.
  ///
  /// This is a stub that is always free. Task 6.7 replaces the body of
  /// [build] with the real entitlement and keeps this name and [PremiumState].
  PremiumProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'premiumProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$premiumHash();

  @$internal
  @override
  Premium create() => Premium();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PremiumState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PremiumState>(value),
    );
  }
}

String _$premiumHash() => r'dc8b866e6576ed9fa838fbffcebe28030c5edffa';

/// The user's Premium state.
///
/// This is a stub that is always free. Task 6.7 replaces the body of
/// [build] with the real entitlement and keeps this name and [PremiumState].

abstract class _$Premium extends $Notifier<PremiumState> {
  PremiumState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PremiumState, PremiumState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PremiumState, PremiumState>,
              PremiumState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
