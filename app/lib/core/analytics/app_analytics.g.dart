// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_analytics.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Where analytics goes: Firebase when it is running, otherwise nowhere.
/// Tests override it with a recording fake.

@ProviderFor(analyticsSink)
final analyticsSinkProvider = AnalyticsSinkProvider._();

/// Where analytics goes: Firebase when it is running, otherwise nowhere.
/// Tests override it with a recording fake.

final class AnalyticsSinkProvider
    extends $FunctionalProvider<AnalyticsSink, AnalyticsSink, AnalyticsSink>
    with $Provider<AnalyticsSink> {
  /// Where analytics goes: Firebase when it is running, otherwise nowhere.
  /// Tests override it with a recording fake.
  AnalyticsSinkProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'analyticsSinkProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$analyticsSinkHash();

  @$internal
  @override
  $ProviderElement<AnalyticsSink> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AnalyticsSink create(Ref ref) {
    return analyticsSink(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AnalyticsSink value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AnalyticsSink>(value),
    );
  }
}

String _$analyticsSinkHash() => r'4a4281460cb73eddf975b71ef4d4d6969d092e77';

/// Whether a guard violation throws (a debug build) instead of dropping the
/// event (release). A seam so tests can act as either.

@ProviderFor(analyticsDebugBuild)
final analyticsDebugBuildProvider = AnalyticsDebugBuildProvider._();

/// Whether a guard violation throws (a debug build) instead of dropping the
/// event (release). A seam so tests can act as either.

final class AnalyticsDebugBuildProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether a guard violation throws (a debug build) instead of dropping the
  /// event (release). A seam so tests can act as either.
  AnalyticsDebugBuildProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'analyticsDebugBuildProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$analyticsDebugBuildHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return analyticsDebugBuild(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$analyticsDebugBuildHash() =>
    r'891f8c023e42468199cf48b860cf3c9be6707325';

/// The one door analytics goes through.
///
/// 1. The guard checks every event and screen name against the catalogue
///    (Ruling P6-R6): a debug build throws [AnalyticsPolicyError], a release
///    build drops the event.
/// 2. The privacy gate (Ruling P6-R4): sharing allowed sends it, undecided
///    keeps it in a buffer of the latest [analyticsBufferSize], denied drops
///    it.
/// 3. The sink gets the native on/off switch on every change of the choice.
///    When sharing turns out allowed the buffer is sent in order; when it
///    turns out denied the buffer is emptied.
///
/// A failing sink is never visible to callers. The app keeps this provider
/// listened to (through `analyticsHooksProvider`): Riverpod pauses a provider
/// nothing listens to, and its listener to the choice would stop.

@ProviderFor(AppAnalytics)
final appAnalyticsProvider = AppAnalyticsProvider._();

/// The one door analytics goes through.
///
/// 1. The guard checks every event and screen name against the catalogue
///    (Ruling P6-R6): a debug build throws [AnalyticsPolicyError], a release
///    build drops the event.
/// 2. The privacy gate (Ruling P6-R4): sharing allowed sends it, undecided
///    keeps it in a buffer of the latest [analyticsBufferSize], denied drops
///    it.
/// 3. The sink gets the native on/off switch on every change of the choice.
///    When sharing turns out allowed the buffer is sent in order; when it
///    turns out denied the buffer is emptied.
///
/// A failing sink is never visible to callers. The app keeps this provider
/// listened to (through `analyticsHooksProvider`): Riverpod pauses a provider
/// nothing listens to, and its listener to the choice would stop.
final class AppAnalyticsProvider extends $NotifierProvider<AppAnalytics, void> {
  /// The one door analytics goes through.
  ///
  /// 1. The guard checks every event and screen name against the catalogue
  ///    (Ruling P6-R6): a debug build throws [AnalyticsPolicyError], a release
  ///    build drops the event.
  /// 2. The privacy gate (Ruling P6-R4): sharing allowed sends it, undecided
  ///    keeps it in a buffer of the latest [analyticsBufferSize], denied drops
  ///    it.
  /// 3. The sink gets the native on/off switch on every change of the choice.
  ///    When sharing turns out allowed the buffer is sent in order; when it
  ///    turns out denied the buffer is emptied.
  ///
  /// A failing sink is never visible to callers. The app keeps this provider
  /// listened to (through `analyticsHooksProvider`): Riverpod pauses a provider
  /// nothing listens to, and its listener to the choice would stop.
  AppAnalyticsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appAnalyticsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appAnalyticsHash();

  @$internal
  @override
  AppAnalytics create() => AppAnalytics();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$appAnalyticsHash() => r'e548b83f8e96f5c244411ccb629be7b86760ca4d';

/// The one door analytics goes through.
///
/// 1. The guard checks every event and screen name against the catalogue
///    (Ruling P6-R6): a debug build throws [AnalyticsPolicyError], a release
///    build drops the event.
/// 2. The privacy gate (Ruling P6-R4): sharing allowed sends it, undecided
///    keeps it in a buffer of the latest [analyticsBufferSize], denied drops
///    it.
/// 3. The sink gets the native on/off switch on every change of the choice.
///    When sharing turns out allowed the buffer is sent in order; when it
///    turns out denied the buffer is emptied.
///
/// A failing sink is never visible to callers. The app keeps this provider
/// listened to (through `analyticsHooksProvider`): Riverpod pauses a provider
/// nothing listens to, and its listener to the choice would stop.

abstract class _$AppAnalytics extends $Notifier<void> {
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
