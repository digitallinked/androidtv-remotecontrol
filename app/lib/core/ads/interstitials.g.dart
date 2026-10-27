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
///
/// The app keeps this provider listened to (`App` watches it): Riverpod
/// pauses a provider nothing listens to, and the listeners below with it.

@ProviderFor(Interstitials)
final interstitialsProvider = InterstitialsProvider._();

/// Interstitial pacing (Ruling P6-R9). They are off unless Remote Config
/// turns them on.
///
/// One ad is kept loaded in advance, so [maybeShow] never waits for a load:
/// an ad that isn't ready is simply not shown. Nothing here throws.
///
/// The app keeps this provider listened to (`App` watches it): Riverpod
/// pauses a provider nothing listens to, and the listeners below with it.
final class InterstitialsProvider
    extends $NotifierProvider<Interstitials, void> {
  /// Interstitial pacing (Ruling P6-R9). They are off unless Remote Config
  /// turns them on.
  ///
  /// One ad is kept loaded in advance, so [maybeShow] never waits for a load:
  /// an ad that isn't ready is simply not shown. Nothing here throws.
  ///
  /// The app keeps this provider listened to (`App` watches it): Riverpod
  /// pauses a provider nothing listens to, and the listeners below with it.
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

String _$interstitialsHash() => r'3995153ccdbcb1bb63086f48b317a7eb58f34fd7';

/// Interstitial pacing (Ruling P6-R9). They are off unless Remote Config
/// turns them on.
///
/// One ad is kept loaded in advance, so [maybeShow] never waits for a load:
/// an ad that isn't ready is simply not shown. Nothing here throws.
///
/// The app keeps this provider listened to (`App` watches it): Riverpod
/// pauses a provider nothing listens to, and the listeners below with it.

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
