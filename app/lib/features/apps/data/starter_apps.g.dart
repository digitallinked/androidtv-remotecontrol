// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'starter_apps.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The apps in the remote's quick-access row.
///
/// Phase 5.1 replaces this body with the catalogue and the user's shortcuts;
/// until then it returns [kStarterApps].

@ProviderFor(quickAccessApps)
final quickAccessAppsProvider = QuickAccessAppsProvider._();

/// The apps in the remote's quick-access row.
///
/// Phase 5.1 replaces this body with the catalogue and the user's shortcuts;
/// until then it returns [kStarterApps].

final class QuickAccessAppsProvider
    extends $FunctionalProvider<List<AppEntry>, List<AppEntry>, List<AppEntry>>
    with $Provider<List<AppEntry>> {
  /// The apps in the remote's quick-access row.
  ///
  /// Phase 5.1 replaces this body with the catalogue and the user's shortcuts;
  /// until then it returns [kStarterApps].
  QuickAccessAppsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'quickAccessAppsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$quickAccessAppsHash();

  @$internal
  @override
  $ProviderElement<List<AppEntry>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<AppEntry> create(Ref ref) {
    return quickAccessApps(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<AppEntry> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<AppEntry>>(value),
    );
  }
}

String _$quickAccessAppsHash() => r'd1da09db90aa133c691038508fe504b67ee3df65';
