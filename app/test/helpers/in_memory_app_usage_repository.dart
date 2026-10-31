import 'dart:async';

import 'package:tv_remote/features/apps/data/app_usage_repository.dart';

/// An [AppUsageRepository] in memory, for widget tests: drift's own
/// `watch()` leaves a timer behind when it is disposed, which fails the test.
///
/// Mirrors [DriftAppUsageRepository]: `watchMostUsed` replays the current
/// list and then every change.
class InMemoryAppUsageRepository implements AppUsageRepository {
  /// Creates a repository holding [initial].
  InMemoryAppUsageRepository([Iterable<AppUsageStat> initial = const []]) {
    for (final stat in initial) {
      stats[stat.package] = stat;
    }
  }

  /// The stats by package.
  final Map<String, AppUsageStat> stats = {};

  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// How many write calls were made, failed ones included.
  int writes = 0;

  /// When set, the next write throws it and clears it.
  Object? failNextWrite;

  List<AppUsageStat> _mostUsed(
    int limit,
    bool Function(String package)? exclude,
  ) {
    final sorted = stats.values.toList()
      ..sort((a, b) {
        final byCount = b.seenCount.compareTo(a.seenCount);
        if (byCount != 0) return byCount;
        final byTime = b.lastSeenAt.compareTo(a.lastSeenAt);
        return byTime != 0 ? byTime : a.package.compareTo(b.package);
      });
    return sorted
        .where((s) => exclude == null || !exclude(s.package))
        .take(limit)
        .toList();
  }

  /// Forgets every package outside the [AppUsageRepository.kUsageKeep] most
  /// recently seen (ties broken by package, as in the drift repository).
  void _prune() {
    if (stats.length <= AppUsageRepository.kUsageKeep) return;
    final newestFirst = stats.values.toList()
      ..sort((a, b) {
        final byTime = b.lastSeenAt.compareTo(a.lastSeenAt);
        return byTime != 0 ? byTime : a.package.compareTo(b.package);
      });
    for (final old in newestFirst.skip(AppUsageRepository.kUsageKeep)) {
      stats.remove(old.package);
    }
  }

  @override
  Future<void> recordSeen(String package, DateTime at) async {
    writes++;
    final failure = failNextWrite;
    if (failure != null) {
      failNextWrite = null;
      // The test chose what to throw, an Error or not.
      // ignore: only_throw_errors
      throw failure;
    }
    final old = stats[package];
    stats[package] = AppUsageStat(
      package: package,
      seenCount: (old?.seenCount ?? 0) + 1,
      lastSeenAt: at.toUtc(),
    );
    _prune();
    if (!_changes.isClosed) _changes.add(null);
  }

  @override
  Stream<List<AppUsageStat>> watchMostUsed({
    int limit = 30,
    bool Function(String package)? exclude,
  }) => Stream.multi((controller) {
    controller.add(_mostUsed(limit, exclude));
    final sub = _changes.stream.listen(
      (_) => controller.add(_mostUsed(limit, exclude)),
    );
    controller.onCancel = sub.cancel;
  });
}
