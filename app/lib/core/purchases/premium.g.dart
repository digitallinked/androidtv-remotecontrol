// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'premium.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The user's Premium state (Ruling P6-R10).
///
/// It starts from the last entitlement the phone saw, so a Premium user never
/// sees an ad while offline or before the store answers. With a configured
/// service the answer is [PremiumState.known] on the first live entitlement,
/// or after [premiumKnownTimeout]; with none (a build with no key) the cache
/// is final at once. Every live answer rewrites the cache.
///
/// Nothing here throws into the UI: a failing store leaves the cached state.

@ProviderFor(Premium)
final premiumProvider = PremiumProvider._();

/// The user's Premium state (Ruling P6-R10).
///
/// It starts from the last entitlement the phone saw, so a Premium user never
/// sees an ad while offline or before the store answers. With a configured
/// service the answer is [PremiumState.known] on the first live entitlement,
/// or after [premiumKnownTimeout]; with none (a build with no key) the cache
/// is final at once. Every live answer rewrites the cache.
///
/// Nothing here throws into the UI: a failing store leaves the cached state.
final class PremiumProvider extends $NotifierProvider<Premium, PremiumState> {
  /// The user's Premium state (Ruling P6-R10).
  ///
  /// It starts from the last entitlement the phone saw, so a Premium user never
  /// sees an ad while offline or before the store answers. With a configured
  /// service the answer is [PremiumState.known] on the first live entitlement,
  /// or after [premiumKnownTimeout]; with none (a build with no key) the cache
  /// is final at once. Every live answer rewrites the cache.
  ///
  /// Nothing here throws into the UI: a failing store leaves the cached state.
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

String _$premiumHash() => r'e1348632c40e540a3c6d47fba63255e667389e32';

/// The user's Premium state (Ruling P6-R10).
///
/// It starts from the last entitlement the phone saw, so a Premium user never
/// sees an ad while offline or before the store answers. With a configured
/// service the answer is [PremiumState.known] on the first live entitlement,
/// or after [premiumKnownTimeout]; with none (a build with no key) the cache
/// is final at once. Every live answer rewrites the cache.
///
/// Nothing here throws into the UI: a failing store leaves the cached state.

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
