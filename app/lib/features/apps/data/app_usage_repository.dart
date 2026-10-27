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
  /// Counts one sighting of [package] at [at]: inserts it with a count of 1,
  /// or adds 1 and stamps [at].
  Future<void> recordSeen(String package, DateTime at);

  /// Emits the most used apps (highest count first, then most recent), at
  /// most [limit]: the current list first, then every change.
  Stream<List<AppUsageStat>> watchMostUsed({int limit = 30});
}

/// [AppUsageRepository] backed by the drift [AppDatabase].
class DriftAppUsageRepository implements AppUsageRepository {
  /// Creates a repository over [_db].
  DriftAppUsageRepository(this._db);

  final AppDatabase _db;

  @override
  Future<void> recordSeen(String package, DateTime at) async {
    await _db
        .into(_db.appUsage)
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
  }

  @override
  Stream<List<AppUsageStat>> watchMostUsed({int limit = 30}) =>
      (_db.select(_db.appUsage)
            ..orderBy([
              (t) => OrderingTerm.desc(t.seenCount),
              (t) => OrderingTerm.desc(t.lastSeenAt),
              (t) => OrderingTerm.asc(t.package),
            ])
            ..limit(limit))
          .watch()
          .map(
            (rows) => [
              for (final r in rows)
                AppUsageStat(
                  package: r.package,
                  seenCount: r.seenCount,
                  // Drift reads DateTime back in local time (learnings).
                  lastSeenAt: r.lastSeenAt.toUtc(),
                ),
            ],
          );
}
