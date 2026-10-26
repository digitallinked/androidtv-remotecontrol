// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_info.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Reads the app's package info and the phone's system version.
///
/// Fails when the platform can't answer. Callers show "unavailable" and carry
/// on; a retry would not help, so there isn't one.

@ProviderFor(appInfo)
final appInfoProvider = AppInfoProvider._();

/// Reads the app's package info and the phone's system version.
///
/// Fails when the platform can't answer. Callers show "unavailable" and carry
/// on; a retry would not help, so there isn't one.

final class AppInfoProvider
    extends $FunctionalProvider<AsyncValue<AppInfo>, AppInfo, FutureOr<AppInfo>>
    with $FutureModifier<AppInfo>, $FutureProvider<AppInfo> {
  /// Reads the app's package info and the phone's system version.
  ///
  /// Fails when the platform can't answer. Callers show "unavailable" and carry
  /// on; a retry would not help, so there isn't one.
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

String _$appInfoHash() => r'783379d07c2115a07f520313613df6a045d84db5';
