// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analytics_hooks.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Chooses which key presses are logged: a value from 0 up to (not including)
/// 1; a press is logged when it is below [keyPressSampleRate]. Tests replace
/// it with a fixed sequence.

@ProviderFor(analyticsSampler)
final analyticsSamplerProvider = AnalyticsSamplerProvider._();

/// Chooses which key presses are logged: a value from 0 up to (not including)
/// 1; a press is logged when it is below [keyPressSampleRate]. Tests replace
/// it with a fixed sequence.

final class AnalyticsSamplerProvider
    extends
        $FunctionalProvider<
          double Function(),
          double Function(),
          double Function()
        >
    with $Provider<double Function()> {
  /// Chooses which key presses are logged: a value from 0 up to (not including)
  /// 1; a press is logged when it is below [keyPressSampleRate]. Tests replace
  /// it with a fixed sequence.
  AnalyticsSamplerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'analyticsSamplerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$analyticsSamplerHash();

  @$internal
  @override
  $ProviderElement<double Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  double Function() create(Ref ref) {
    return analyticsSampler(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<double Function()>(value),
    );
  }
}

String _$analyticsSamplerHash() => r'76034ba4ff27f5e270c6f99fa3c8c676ce9b92c3';

/// Connects analytics to the parts of the app that happen on their own: the
/// connection (`connect_success`, `connect_lost`) and the layout settings
/// (`layout_change`), and offers the remote's hooks.
///
/// The app reads it once at start. Its listeners need it to stay listened to,
/// which `App` does.

@ProviderFor(analyticsHooks)
final analyticsHooksProvider = AnalyticsHooksProvider._();

/// Connects analytics to the parts of the app that happen on their own: the
/// connection (`connect_success`, `connect_lost`) and the layout settings
/// (`layout_change`), and offers the remote's hooks.
///
/// The app reads it once at start. Its listeners need it to stay listened to,
/// which `App` does.

final class AnalyticsHooksProvider
    extends $FunctionalProvider<AnalyticsHooks, AnalyticsHooks, AnalyticsHooks>
    with $Provider<AnalyticsHooks> {
  /// Connects analytics to the parts of the app that happen on their own: the
  /// connection (`connect_success`, `connect_lost`) and the layout settings
  /// (`layout_change`), and offers the remote's hooks.
  ///
  /// The app reads it once at start. Its listeners need it to stay listened to,
  /// which `App` does.
  AnalyticsHooksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'analyticsHooksProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$analyticsHooksHash();

  @$internal
  @override
  $ProviderElement<AnalyticsHooks> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AnalyticsHooks create(Ref ref) {
    return analyticsHooks(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AnalyticsHooks value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AnalyticsHooks>(value),
    );
  }
}

String _$analyticsHooksHash() => r'b1bbf9922d21e28f421ebf2c37ee0d4240db2d4f';
