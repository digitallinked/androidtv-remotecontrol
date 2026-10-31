// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shortcuts.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Fills the shortcut list with the region's default row the first time it
/// is needed (Ruling P5-R5), then sets the `shortcutsSeeded` flag.
///
/// The row is written only while the table is empty, so a crash between the
/// write and the flag never duplicates anything, and a list the user emptied
/// later (flag set) is never refilled. Errors (a corrupt catalogue, storage
/// that won't open) are swallowed: the flag stays unset and the next launch
/// tries again.

@ProviderFor(shortcutsSeed)
final shortcutsSeedProvider = ShortcutsSeedProvider._();

/// Fills the shortcut list with the region's default row the first time it
/// is needed (Ruling P5-R5), then sets the `shortcutsSeeded` flag.
///
/// The row is written only while the table is empty, so a crash between the
/// write and the flag never duplicates anything, and a list the user emptied
/// later (flag set) is never refilled. Errors (a corrupt catalogue, storage
/// that won't open) are swallowed: the flag stays unset and the next launch
/// tries again.

final class ShortcutsSeedProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// Fills the shortcut list with the region's default row the first time it
  /// is needed (Ruling P5-R5), then sets the `shortcutsSeeded` flag.
  ///
  /// The row is written only while the table is empty, so a crash between the
  /// write and the flag never duplicates anything, and a list the user emptied
  /// later (flag set) is never refilled. Errors (a corrupt catalogue, storage
  /// that won't open) are swallowed: the flag stays unset and the next launch
  /// tries again.
  ShortcutsSeedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shortcutsSeedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shortcutsSeedHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return shortcutsSeed(ref);
  }
}

String _$shortcutsSeedHash() => r'9217a8770e36bbc323d84e0b3c3ce2abd1d4f963';

/// The user's shortcuts by position, once the first-run seeding is done.
///
/// A read failure is shown at once ([noRetry], Ruling P8-R10): the Apps
/// screen offers "Try again" itself.

@ProviderFor(shortcuts)
final shortcutsProvider = ShortcutsProvider._();

/// The user's shortcuts by position, once the first-run seeding is done.
///
/// A read failure is shown at once ([noRetry], Ruling P8-R10): the Apps
/// screen offers "Try again" itself.

final class ShortcutsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AppEntry>>,
          List<AppEntry>,
          Stream<List<AppEntry>>
        >
    with $FutureModifier<List<AppEntry>>, $StreamProvider<List<AppEntry>> {
  /// The user's shortcuts by position, once the first-run seeding is done.
  ///
  /// A read failure is shown at once ([noRetry], Ruling P8-R10): the Apps
  /// screen offers "Try again" itself.
  ShortcutsProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'shortcutsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shortcutsHash();

  @$internal
  @override
  $StreamProviderElement<List<AppEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<AppEntry>> create(Ref ref) {
    return shortcuts(ref);
  }
}

String _$shortcutsHash() => r'970dbe160f9d7941157392b66019e3eb4875ee45';

/// The [ShortcutActions] for the widgets.

@ProviderFor(shortcutActions)
final shortcutActionsProvider = ShortcutActionsProvider._();

/// The [ShortcutActions] for the widgets.

final class ShortcutActionsProvider
    extends
        $FunctionalProvider<ShortcutActions, ShortcutActions, ShortcutActions>
    with $Provider<ShortcutActions> {
  /// The [ShortcutActions] for the widgets.
  ShortcutActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shortcutActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shortcutActionsHash();

  @$internal
  @override
  $ProviderElement<ShortcutActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ShortcutActions create(Ref ref) {
    return shortcutActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShortcutActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShortcutActions>(value),
    );
  }
}

String _$shortcutActionsHash() => r'3d779c20ee8616bfb33606248683e6510c557b23';

/// The most used apps seen on the TV, kept up to date. System packages are
/// dropped before the limit (Ruling P8-R10), so they never crowd out the
/// apps worth recommending.

@ProviderFor(appUsage)
final appUsageProvider = AppUsageProvider._();

/// The most used apps seen on the TV, kept up to date. System packages are
/// dropped before the limit (Ruling P8-R10), so they never crowd out the
/// apps worth recommending.

final class AppUsageProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AppUsageStat>>,
          List<AppUsageStat>,
          Stream<List<AppUsageStat>>
        >
    with
        $FutureModifier<List<AppUsageStat>>,
        $StreamProvider<List<AppUsageStat>> {
  /// The most used apps seen on the TV, kept up to date. System packages are
  /// dropped before the limit (Ruling P8-R10), so they never crowd out the
  /// apps worth recommending.
  AppUsageProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'appUsageProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appUsageHash();

  @$internal
  @override
  $StreamProviderElement<List<AppUsageStat>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<AppUsageStat>> create(Ref ref) {
    return appUsage(ref);
  }
}

String _$appUsageHash() => r'e811eab5e3c7fd521f98385dea3f8a4d3482bd9c';

/// "Recently used on your TV": see [recommendApps]. An error state when the
/// catalogue or the usage can't be read, shown at once ([noRetry]).

@ProviderFor(recommendedApps)
final recommendedAppsProvider = RecommendedAppsProvider._();

/// "Recently used on your TV": see [recommendApps]. An error state when the
/// catalogue or the usage can't be read, shown at once ([noRetry]).

final class RecommendedAppsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AppEntry>>,
          List<AppEntry>,
          FutureOr<List<AppEntry>>
        >
    with $FutureModifier<List<AppEntry>>, $FutureProvider<List<AppEntry>> {
  /// "Recently used on your TV": see [recommendApps]. An error state when the
  /// catalogue or the usage can't be read, shown at once ([noRetry]).
  RecommendedAppsProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'recommendedAppsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recommendedAppsHash();

  @$internal
  @override
  $FutureProviderElement<List<AppEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AppEntry>> create(Ref ref) {
    return recommendedApps(ref);
  }
}

String _$recommendedAppsHash() => r'9fb75aa7cb4b317f323d742271c0d7f284211c54';

/// Counts each app that comes to the TV's foreground (Ruling P5-R6).
///
/// An app is counted when it differs from the last one counted; the demo TV
/// is never counted, and a storage error is ignored. Listen to it from the
/// remote screen to keep it alive.

@ProviderFor(appUsageTracker)
final appUsageTrackerProvider = AppUsageTrackerProvider._();

/// Counts each app that comes to the TV's foreground (Ruling P5-R6).
///
/// An app is counted when it differs from the last one counted; the demo TV
/// is never counted, and a storage error is ignored. Listen to it from the
/// remote screen to keep it alive.

final class AppUsageTrackerProvider
    extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// Counts each app that comes to the TV's foreground (Ruling P5-R6).
  ///
  /// An app is counted when it differs from the last one counted; the demo TV
  /// is never counted, and a storage error is ignored. Listen to it from the
  /// remote screen to keep it alive.
  AppUsageTrackerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appUsageTrackerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appUsageTrackerHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return appUsageTracker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$appUsageTrackerHash() => r'8834f72fcfb611f93a41466c0b92e8368500a12d';
