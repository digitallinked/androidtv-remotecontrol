import 'package:drift/drift.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';

/// Storage for the user's app shortcuts (global, one per package).
///
/// Shortcuts are ordered by position. Every write that changes the order
/// leaves the positions dense (0..n-1).
abstract interface class ShortcutRepository {
  /// Emits the shortcuts by position: the current list first, then every
  /// change.
  Stream<List<AppEntry>> watchAll();

  /// The shortcuts by position.
  Future<List<AppEntry>> all();

  /// How many shortcuts there are.
  Future<int> count();

  /// Appends [app] and returns `true`, or returns `false` without writing
  /// when a shortcut with that package already exists.
  Future<bool> add(AppEntry app);

  /// Changes the name, launch link, custom flag, colour and icon of the
  /// shortcut with [app]'s package. Does nothing when there is none.
  Future<void> update(AppEntry app);

  /// Removes the shortcut with [package]; the others close the gap.
  Future<void> remove(String package);

  /// Puts the listed [packages] first, in that order; the others follow in
  /// their old order. Unknown and repeated packages are ignored.
  Future<void> reorder(List<String> packages);

  /// Replaces the whole list with [apps] in one transaction. A package that
  /// repeats is dropped after its first occurrence.
  Future<void> replaceAll(List<AppEntry> apps);

  /// Inserts [apps] (a repeated package is dropped after its first
  /// occurrence, positions 0..n-1) only if there are no shortcuts, in one
  /// transaction. Returns whether it inserted them. First-run seeding uses it,
  /// so rows added in the meantime are never overwritten.
  Future<bool> seedIfEmpty(List<AppEntry> apps);
}

/// [ShortcutRepository] backed by the drift [AppDatabase].
class DriftShortcutRepository implements ShortcutRepository {
  /// Creates a repository over [_db].
  DriftShortcutRepository(this._db);

  final AppDatabase _db;

  static AppEntry _toEntry(ShortcutRow row) => AppEntry(
    package: row.package,
    name: row.name,
    launchLink: row.launchLink,
    iconUrl: row.iconUrl,
    isCustom: row.isCustom,
    customColor: row.customColor == null ? null : Color(row.customColor!),
    customIcon: row.customIcon,
  );

  SimpleSelectStatement<$ShortcutsTable, ShortcutRow> _ordered() =>
      _db.select(_db.shortcuts)..orderBy([
        (t) => OrderingTerm.asc(t.position),
        (t) => OrderingTerm.asc(t.id),
      ]);

  ShortcutsCompanion _insertion(AppEntry app, int position) =>
      ShortcutsCompanion.insert(
        package: app.package,
        name: app.name,
        launchLink: app.launchLink,
        iconUrl: Value(app.iconUrl),
        isCustom: Value(app.isCustom),
        customColor: Value(app.customColor?.toARGB32()),
        customIcon: Value(app.customIcon),
        position: position,
      );

  /// Rewrites positions to 0..n-1 in the given row order.
  Future<void> _renumber(List<ShortcutRow> rows) async {
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].position == i) continue;
      await (_db.update(_db.shortcuts)..where((t) => t.id.equals(rows[i].id)))
          .write(ShortcutsCompanion(position: Value(i)));
    }
  }

  @override
  Stream<List<AppEntry>> watchAll() =>
      _ordered().watch().map((rows) => rows.map(_toEntry).toList());

  @override
  Future<List<AppEntry>> all() async =>
      (await _ordered().get()).map(_toEntry).toList();

  @override
  Future<int> count() async {
    final count = _db.shortcuts.id.count();
    final query = _db.selectOnly(_db.shortcuts)..addColumns([count]);
    return (await query.getSingle()).read(count) ?? 0;
  }

  @override
  Future<bool> add(AppEntry app) => _db.transaction(() async {
    final existing = await (_db.select(
      _db.shortcuts,
    )..where((t) => t.package.equals(app.package))).getSingleOrNull();
    if (existing != null) return false;
    final rows = await _ordered().get();
    await _db.into(_db.shortcuts).insert(_insertion(app, rows.length));
    return true;
  });

  @override
  Future<void> update(AppEntry app) async {
    await (_db.update(
      _db.shortcuts,
    )..where((t) => t.package.equals(app.package))).write(
      ShortcutsCompanion(
        name: Value(app.name),
        launchLink: Value(app.launchLink),
        isCustom: Value(app.isCustom),
        customColor: Value(app.customColor?.toARGB32()),
        customIcon: Value(app.customIcon),
      ),
    );
  }

  @override
  Future<void> remove(String package) => _db.transaction(() async {
    await (_db.delete(
      _db.shortcuts,
    )..where((t) => t.package.equals(package))).go();
    await _renumber(await _ordered().get());
  });

  @override
  Future<void> reorder(List<String> packages) => _db.transaction(() async {
    final rows = await _ordered().get();
    final byPackage = {for (final r in rows) r.package: r};
    final first = <ShortcutRow>[];
    for (final p in packages) {
      final row = byPackage.remove(p);
      if (row != null) first.add(row);
    }
    await _renumber([...first, ...byPackage.values]);
  });

  @override
  Future<void> replaceAll(List<AppEntry> apps) => _db.transaction(() async {
    await _db.delete(_db.shortcuts).go();
    await _insertAll(apps);
  });

  @override
  Future<bool> seedIfEmpty(List<AppEntry> apps) => _db.transaction(() async {
    if (await count() > 0) return false;
    await _insertAll(apps);
    return true;
  });

  Future<void> _insertAll(List<AppEntry> apps) async {
    final seen = <String>{};
    var position = 0;
    for (final app in apps) {
      if (!seen.add(app.package)) continue;
      await _db.into(_db.shortcuts).insert(_insertion(app, position++));
    }
  }
}
