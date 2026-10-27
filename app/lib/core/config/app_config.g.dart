// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_config.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The configuration source: Firebase Remote Config when Firebase is ready
/// (fetch interval 1 h for prod, 5 min for dev), else defaults only.

@ProviderFor(remoteConfigSource)
final remoteConfigSourceProvider = RemoteConfigSourceProvider._();

/// The configuration source: Firebase Remote Config when Firebase is ready
/// (fetch interval 1 h for prod, 5 min for dev), else defaults only.

final class RemoteConfigSourceProvider
    extends
        $FunctionalProvider<
          RemoteConfigSource,
          RemoteConfigSource,
          RemoteConfigSource
        >
    with $Provider<RemoteConfigSource> {
  /// The configuration source: Firebase Remote Config when Firebase is ready
  /// (fetch interval 1 h for prod, 5 min for dev), else defaults only.
  RemoteConfigSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'remoteConfigSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$remoteConfigSourceHash();

  @$internal
  @override
  $ProviderElement<RemoteConfigSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RemoteConfigSource create(Ref ref) {
    return remoteConfigSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RemoteConfigSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RemoteConfigSource>(value),
    );
  }
}

String _$remoteConfigSourceHash() =>
    r'66a526e79bd189261d0e2f8f978cb515265fa5b9';

/// The Remote Config values for this session.
///
/// The state is [AppConfigValues.defaults] until [load] has activated the
/// values fetched on an earlier launch, and it never changes after that, so
/// nothing flips mid-session.

@ProviderFor(AppConfig)
final appConfigProvider = AppConfigProvider._();

/// The Remote Config values for this session.
///
/// The state is [AppConfigValues.defaults] until [load] has activated the
/// values fetched on an earlier launch, and it never changes after that, so
/// nothing flips mid-session.
final class AppConfigProvider
    extends $NotifierProvider<AppConfig, AppConfigValues> {
  /// The Remote Config values for this session.
  ///
  /// The state is [AppConfigValues.defaults] until [load] has activated the
  /// values fetched on an earlier launch, and it never changes after that, so
  /// nothing flips mid-session.
  AppConfigProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appConfigProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appConfigHash();

  @$internal
  @override
  AppConfig create() => AppConfig();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppConfigValues value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppConfigValues>(value),
    );
  }
}

String _$appConfigHash() => r'eb6ff3dc196abca763276aff9240f13577bad5d7';

/// The Remote Config values for this session.
///
/// The state is [AppConfigValues.defaults] until [load] has activated the
/// values fetched on an earlier launch, and it never changes after that, so
/// nothing flips mid-session.

abstract class _$AppConfig extends $Notifier<AppConfigValues> {
  AppConfigValues build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AppConfigValues, AppConfigValues>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppConfigValues, AppConfigValues>,
              AppConfigValues,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
