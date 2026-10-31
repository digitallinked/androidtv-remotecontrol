import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:tv_remote/core/storage/app_database.dart';

/// How often an app has been seen in the TV's foreground (on this phone only).
@immutable
class AppUsageStat {
  /// Creates a stat.
  const AppUsageStat({
    required this.package,
    required this.seenCount,
    required this.lastSeenAt,
  });

  /// The Android application id.
  final String package;

  /// How many times the app has been seen.
  final int seenCount;

  /// When the app was last seen.
  final DateTime lastSeenAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUsageStat &&
          other.package == package &&
          other.seenCount == seenCount &&
          other.lastSeenAt == lastSeenAt;

  @override
  int get hashCode => Object.hash(package, seenCount, lastSeenAt);

  @override
  String toString() => 'AppUsageStat($package, $seenCount, $lastSeenAt)';
}

/// Storage for app usage counts (global, kept on the phone).
abstract interface class AppUsageRepository {
  /// How many packages are kept: the most recently seen ones (Ruling
  /// P8-R10).
  static const int kUsageKeep = 200;

  /// Counts one sighting of [package] at [at]: inserts it with a count of 1,
  /// or adds 1 and stamps [at]. Then forgets every package outside the
  /// [kUsageKeep] most recently seen, in the same transaction.
  ///
  /// The prune goes by recency only: a sighting whose [at] is older than
  /// the [kUsageKeep]th newest (the clock went backwards) is forgotten at
  /// once, in the same call.
  Future<void> recordSeen(String package, DateTime at);

  /// Emits the most used apps (highest count first, then most recent), at
  /// most [limit]: the current list first, then every change.
  ///
  /// Packages for which [exclude] is true are dropped before [limit] is
  /// applied, so many hidden packages never crowd out the rest.
  Stream<List<AppUsageStat>> watchMostUsed({
    int limit = 30,
    bool Function(String package)? exclude,
  });
}

/// [AppUsageRepository] backed by the drift [AppDatabase].
class DriftAppUsageRepository implements AppUsageRepository {
  /// Creates a repository over [_db].
  DriftAppUsageRepository(this._db);

  final AppDatabase _db;

  @override
  Future<void> recordSeen(String package, DateTime at) => _db.transaction(
    () async {
      final usage = _db.appUsage;
      await _db
          .into(usage)
          .insert(
            AppUsageCompanion.insert(
              package: package,
              lastSeenAt: at,
              seenCount: const Value(1),
            ),
            onConflict: DoUpdate(
              (old) => AppUsageCompanion.custom(
                seenCount: old.seenCount + const Constant(1),
                lastSeenAt: Variable<DateTime>(at),
              ),
            ),
          );
      // Ties in time are broken by package, as in the in-memory fake.
      final kept = _db.selectOnly(usage)
        ..addColumns([usage.package])
        ..orderBy([
          OrderingTerm.desc(usage.lastSeenAt),
          OrderingTerm.asc(usage.package),
        ])
        ..limit(AppUsageRepository.kUsageKeep);
      await (_db.delete(
        usage,
      )..where((t) => t.package.isNotInQuery(kept))).go();
    },
  );

  @override
  Stream<List<AppUsageStat>> watchMostUsed({
    int limit = 30,
    bool Function(String package)? exclude,
  }) {
    final query = _db.select(_db.appUsage)
      ..orderBy([
        (t) => OrderingTerm.desc(t.seenCount),
        (t) => OrderingTerm.desc(t.lastSeenAt),
        (t) => OrderingTerm.asc(t.package),
      ]);
    // A filter can't run in SQL: read every row (at most kUsageKeep) and
    // apply the limit after it.
    if (exclude == null) query.limit(limit);
    return query.watch().map(
      (rows) => [
        for (final r in rows)
          if (exclude == null || !exclude(r.package))
            AppUsageStat(
              package: r.package,
              seenCount: r.seenCount,
              // Drift reads DateTime back in local time (learnings).
              lastSeenAt: r.lastSeenAt.toUtc(),
            ),
      ].take(limit).toList(),
    );
  }
}
