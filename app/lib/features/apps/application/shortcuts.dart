import 'dart:async';

import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/apps/data/app_usage_repository.dart';
import 'package:tv_remote/features/apps/data/apps_data_providers.dart';
import 'package:tv_remote/features/apps/data/catalogue_repository.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';
import 'package:tv_remote/features/apps/domain/recommendations.dart';

part 'shortcuts.g.dart';

/// Fills the shortcut list with the region's default row the first time it
/// is needed (Ruling P5-R5), then sets the `shortcutsSeeded` flag.
///
/// The row is written only while the table is empty, so a crash between the
/// write and the flag never duplicates anything, and a list the user emptied
/// later (flag set) is never refilled. Errors (a corrupt catalogue, storage
/// that won't open) are swallowed: the flag stays unset and the next launch
/// tries again.
@Riverpod(keepAlive: true)
Future<void> shortcutsSeed(Ref ref) async {
  final store = ref.watch(settingsStoreProvider);
  final repository = ref.watch(shortcutRepositoryProvider);
  // Watched before the first await. `ignore` keeps a catalogue error that
  // this run never awaits from surfacing as an unhandled one.
  final catalogueFuture = ref.watch(catalogueProvider.future)..ignore();
  final region = ref.watch(deviceRegionProvider);
  try {
    if (store.shortcutsSeeded) return;
    if (await repository.count() == 0) {
      final catalogue = await catalogueFuture;
      await repository.replaceAll(catalogue.defaultShortcutsFor(region));
    }
    await store.setShortcutsSeeded(true);
  } on Object {
    // Retried on the next launch.
  }
}

/// The user's shortcuts by position, once the first-run seeding is done.
@riverpod
Stream<List<AppEntry>> shortcuts(Ref ref) async* {
  final repository = ref.watch(shortcutRepositoryProvider);
  await ref.watch(shortcutsSeedProvider.future);
  yield* repository.watchAll();
}

/// Changes to the shortcut list. Storage errors propagate to the caller,
/// which shows the "couldn't save" message.
class ShortcutActions {
  /// Creates the actions over [_ref].
  ShortcutActions(this._ref);

  final Ref _ref;

  /// Appends [app]; `false` when its package is already on the list.
  Future<bool> add(AppEntry app) =>
      _ref.read(shortcutRepositoryProvider).add(app);

  /// Changes the shortcut with [app]'s package.
  Future<void> update(AppEntry app) =>
      _ref.read(shortcutRepositoryProvider).update(app);

  /// Removes the shortcut with [package].
  Future<void> remove(String package) =>
      _ref.read(shortcutRepositoryProvider).remove(package);

  /// Puts [packages] first, in that order.
  Future<void> reorder(List<String> packages) =>
      _ref.read(shortcutRepositoryProvider).reorder(packages);

  /// Replaces the whole list with [apps].
  Future<void> replaceAll(List<AppEntry> apps) =>
      _ref.read(shortcutRepositoryProvider).replaceAll(apps);

  /// Replaces the list with the default row of the phone's current region.
  Future<void> resetToDefaults() async {
    // Everything is taken before the first await: this provider may be
    // disposed meanwhile. The region is re-read because it is kept alive.
    final repository = _ref.read(shortcutRepositoryProvider);
    final catalogueFuture = _ref.read(catalogueProvider.future);
    _ref.invalidate(deviceRegionProvider);
    final region = _ref.read(deviceRegionProvider);
    final catalogue = await catalogueFuture;
    await repository.replaceAll(catalogue.defaultShortcutsFor(region));
  }
}

/// The [ShortcutActions] for the widgets.
@riverpod
ShortcutActions shortcutActions(Ref ref) => ShortcutActions(ref);

/// The most used apps seen on the TV, kept up to date.
@riverpod
Stream<List<AppUsageStat>> appUsage(Ref ref) =>
    ref.watch(appUsageRepositoryProvider).watchMostUsed();

/// "Recently used on your TV": see [recommendApps]. An error state when the
/// catalogue can't be read.
@riverpod
Future<List<AppEntry>> recommendedApps(Ref ref) async {
  final usageFuture = ref.watch(appUsageProvider.future);
  final shortcutsFuture = ref.watch(shortcutsProvider.future);
  final catalogueFuture = ref.watch(catalogueProvider.future);
  final usage = await usageFuture;
  final shortcuts = await shortcutsFuture;
  final catalogue = await catalogueFuture;
  return recommendApps(
    usage: usage,
    catalogue: catalogue,
    exclude: {for (final s in shortcuts) s.package},
  );
}

/// Counts each app that comes to the TV's foreground (Ruling P5-R6).
///
/// An app is counted when it differs from the last one counted; the demo TV
/// is never counted, and a storage error is ignored. Listen to it from the
/// remote screen to keep it alive.
@riverpod
void appUsageTracker(Ref ref) {
  String? lastRecorded;
  ref.listen(currentAppProvider, (_, next) {
    final package = switch (next) {
      AsyncData(:final value) => value,
      _ => null,
    };
    if (package == null || package == lastRecorded) return;
    if (ref.read(remoteSessionProvider).value?.isDemo ?? false) return;
    lastRecorded = package;
    try {
      unawaited(
        ref
            .read(appUsageRepositoryProvider)
            .recordSeen(package, clock.now().toUtc())
            .catchError((Object _) {}),
      );
    } on Object {
      // Usage is a convenience; never break the remote for it.
    }
  });
}
