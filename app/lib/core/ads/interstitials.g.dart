// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'interstitials.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Interstitial pacing (Ruling P6-R9). They are off unless Remote Config
/// turns them on.
///
/// One ad is kept loaded in advance, so [maybeShow] never waits for a load:
/// an ad that isn't ready is simply not shown. Nothing here throws.

@ProviderFor(Interstitials)
final interstitialsProvider = InterstitialsProvider._();

/// Interstitial pacing (Ruling P6-R9). They are off unless Remote Config
/// turns them on.
///
/// One ad is kept loaded in advance, so [maybeShow] never waits for a load:
/// an ad that isn't ready is simply not shown. Nothing here throws.
final class InterstitialsProvider
    extends $NotifierProvider<Interstitials, void> {
  /// Interstitial pacing (Ruling P6-R9). They are off unless Remote Config
  /// turns them on.
  ///
  /// One ad is kept loaded in advance, so [maybeShow] never waits for a load:
  /// an ad that isn't ready is simply not shown. Nothing here throws.
  InterstitialsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'interstitialsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$interstitialsHash();

  @$internal
  @override
  Interstitials create() => Interstitials();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$interstitialsHash() => r'94080d503eb452bd51935da2a4a0bb9e217e2645';

/// Interstitial pacing (Ruling P6-R9). They are off unless Remote Config
/// turns them on.
///
/// One ad is kept loaded in advance, so [maybeShow] never waits for a load:
/// an ad that isn't ready is simply not shown. Nothing here throws.

abstract class _$Interstitials extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
