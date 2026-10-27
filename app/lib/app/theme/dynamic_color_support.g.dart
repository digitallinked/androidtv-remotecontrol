// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dynamic_color_support.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the phone can give the app colours from its wallpaper (Android 12
/// and later with a wallpaper palette).
///
/// Settings → Appearance shows the "Colours from wallpaper" switch only when
/// this is `true`. Any error counts as "not supported".

@ProviderFor(dynamicColorSupported)
final dynamicColorSupportedProvider = DynamicColorSupportedProvider._();

/// Whether the phone can give the app colours from its wallpaper (Android 12
/// and later with a wallpaper palette).
///
/// Settings → Appearance shows the "Colours from wallpaper" switch only when
/// this is `true`. Any error counts as "not supported".

final class DynamicColorSupportedProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Whether the phone can give the app colours from its wallpaper (Android 12
  /// and later with a wallpaper palette).
  ///
  /// Settings → Appearance shows the "Colours from wallpaper" switch only when
  /// this is `true`. Any error counts as "not supported".
  DynamicColorSupportedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dynamicColorSupportedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dynamicColorSupportedHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return dynamicColorSupported(ref);
  }
}

String _$dynamicColorSupportedHash() =>
    r'38e11716811734dc3f041e34eaf15718f06b93b1';
