// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_info.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Reads the release the user knows from `device_info_plus`: `Android 12`
/// (`version.release`), `iOS 17.5` (`systemVersion`). Elsewhere, the
/// platform's own strings.

@ProviderFor(osVersionReader)
final osVersionReaderProvider = OsVersionReaderProvider._();

/// Reads the release the user knows from `device_info_plus`: `Android 12`
/// (`version.release`), `iOS 17.5` (`systemVersion`). Elsewhere, the
/// platform's own strings.

final class OsVersionReaderProvider
    extends
        $FunctionalProvider<OsVersionReader, OsVersionReader, OsVersionReader>
    with $Provider<OsVersionReader> {
  /// Reads the release the user knows from `device_info_plus`: `Android 12`
  /// (`version.release`), `iOS 17.5` (`systemVersion`). Elsewhere, the
  /// platform's own strings.
  OsVersionReaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'osVersionReaderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$osVersionReaderHash();

  @$internal
  @override
  $ProviderElement<OsVersionReader> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  OsVersionReader create(Ref ref) {
    return osVersionReader(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OsVersionReader value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OsVersionReader>(value),
    );
  }
}

String _$osVersionReaderHash() => r'd07bca7a31fd0b48d795d410db9f6b7d106f6fcd';

/// Reads the app's package info and the phone's system version.
///
/// The system version never makes this fail: a reader that throws, or takes
/// longer than [osVersionTimeout], gives the platform strings. Package info
/// that can't be read does fail it. Callers show "unavailable" and carry on;
/// a retry would not help, so there isn't one.

@ProviderFor(appInfo)
final appInfoProvider = AppInfoProvider._();

/// Reads the app's package info and the phone's system version.
///
/// The system version never makes this fail: a reader that throws, or takes
/// longer than [osVersionTimeout], gives the platform strings. Package info
/// that can't be read does fail it. Callers show "unavailable" and carry on;
/// a retry would not help, so there isn't one.

final class AppInfoProvider
    extends $FunctionalProvider<AsyncValue<AppInfo>, AppInfo, FutureOr<AppInfo>>
    with $FutureModifier<AppInfo>, $FutureProvider<AppInfo> {
  /// Reads the app's package info and the phone's system version.
  ///
  /// The system version never makes this fail: a reader that throws, or takes
  /// longer than [osVersionTimeout], gives the platform strings. Package info
  /// that can't be read does fail it. Callers show "unavailable" and carry on;
  /// a retry would not help, so there isn't one.
  AppInfoProvider._()
    : super(
        from: null,
        argument: null,
        retry: _noRetry,
        name: r'appInfoProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appInfoHash();

  @$internal
  @override
  $FutureProviderElement<AppInfo> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<AppInfo> create(Ref ref) {
    return appInfo(ref);
  }
}

String _$appInfoHash() => r'08b794a9ad925de98b1a79d274b4bf4badf14e46';
