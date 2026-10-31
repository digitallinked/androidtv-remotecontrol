import 'dart:async';

import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/apps/data/app_usage_repository.dart';
import 'package:tv_remote/features/apps/data/apps_data_providers.dart';
import 'package:tv_remote/features/apps/data/catalogue_repository.dart';
import 'package:tv_remote/features/apps/data/shortcut_repository.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';
import 'package:tv_remote/features/apps/domain/package_names.dart';
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
///
/// The flag lives in the preferences, which an iPhone restore or Quick Start
/// brings back without the database (Ruling P8-R1). A store created in this
/// run is seeded whatever the flag says.
@Riverpod(keepAlive: true)
Future<void> shortcutsSeed(Ref ref) async {
  final store = ref.watch(settingsStoreProvider);
  final repository = ref.watch(shortcutRepositoryProvider);
  if (store.shortcutsSeeded) {
    // Seeded already (every start after the first): the catalogue is not
    // even read, unless the store is new.
    try {
      if (!await repository.isNewStore()) return;
    } on Object {
      // Storage that won't open: the shortcuts read shows the error.
      return;
    }
  }
  // `ignore` keeps a catalogue error that this run never awaits from
  // surfacing as an unhandled one.
  final catalogueFuture = ref.watch(catalogueProvider.future)..ignore();
  final region = ref.watch(deviceRegionProvider);
  try {
    // A crash after the write left rows behind: only the flag is missing.
    if (await repository.count() == 0) {
      final catalogue = await catalogueFuture;
      // One transaction that checks again: a row added while the catalogue
      // loaded is never overwritten.
      await repository.seedIfEmpty(catalogue.defaultShortcutsFor(region));
    }
    await store.setShortcutsSeeded(true);
  } on Object {
    // Retried on the next launch.
  }
}

/// The user's shortcuts by position, once the first-run seeding is done.
///
/// A read failure is shown at once ([noRetry], Ruling P8-R10): the Apps
/// screen offers "Try again" itself.
@Riverpod(retry: noRetry)
Stream<List<AppEntry>> shortcuts(Ref ref) async* {
  final repository = ref.watch(shortcutRepositoryProvider);
  await ref.watch(shortcutsSeedProvider.future);
  yield* repository.watchAll();
}

/// Changes to the shortcut list. Storage errors propagate to the caller,
/// which shows the "couldn't save" message.
///
/// A caller may hold these actions across an await after the provider has
/// been disposed (nothing has to watch it), so everything a call needs is
/// taken when the actions are created, not read from the provider's `Ref`
/// at call time.
class ShortcutActions {
  /// Creates the actions over [ref].
  ShortcutActions(Ref ref)
    : _repository = ref.read(shortcutRepositoryProvider),
      _container = ref.container;

  final ShortcutRepository _repository;

  /// Where the catalogue and the region are read for a reset.
  final ProviderContainer _container;

  /// Appends [app]; `false` when its package is already on the list.
  Future<bool> add(AppEntry app) => _repository.add(app);

  /// Changes the shortcut with [app]'s package.
  Future<void> update(AppEntry app) => _repository.update(app);

  /// Removes the shortcut with [package].
  Future<void> remove(String package) => _repository.remove(package);

  /// Puts [packages] first, in that order.
  Future<void> reorder(List<String> packages) => _repository.reorder(packages);

  /// Replaces the whole list with [apps].
  Future<void> replaceAll(List<AppEntry> apps) => _repository.replaceAll(apps);

  /// Replaces the list with the default row of the phone's current region.
  Future<void> resetToDefaults() async {
    // Everything is read before the first await. The region is re-read
    // because it is kept alive.
    final container = _container;
    final catalogueFuture = container.read(catalogueProvider.future);
    container.invalidate(deviceRegionProvider);
    final region = container.read(deviceRegionProvider);
    final catalogue = await catalogueFuture;
    await _repository.replaceAll(catalogue.defaultShortcutsFor(region));
  }
}

/// The [ShortcutActions] for the widgets.
@riverpod
ShortcutActions shortcutActions(Ref ref) => ShortcutActions(ref);

/// The most used apps seen on the TV, kept up to date. System packages are
/// dropped before the limit (Ruling P8-R10), so they never crowd out the
/// apps worth recommending.
@Riverpod(retry: noRetry)
Stream<List<AppUsageStat>> appUsage(Ref ref) => ref
    .watch(appUsageRepositoryProvider)
    .watchMostUsed(exclude: isSystemPackage);

/// "Recently used on your TV": see [recommendApps]. An error state when the
/// catalogue or the usage can't be read, shown at once ([noRetry]).
@Riverpod(retry: noRetry)
Future<List<AppEntry>> recommendedApps(Ref ref) async {
  final usageFuture = ref.watch(appUsageProvider.future);
  // `ignore`: when one of them fails first, the others are never awaited, and
  // their own failure must not surface as an unhandled error.
  final shortcutsFuture = ref.watch(shortcutsProvider.future)..ignore();
  final catalogueFuture = ref.watch(catalogueProvider.future)..ignore();
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
