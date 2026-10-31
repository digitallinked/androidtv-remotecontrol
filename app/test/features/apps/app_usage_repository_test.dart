import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/features/apps/data/app_usage_repository.dart';
import 'package:tv_remote/features/apps/domain/package_names.dart';

import '../../helpers/in_memory_app_usage_repository.dart';

// Whole seconds: drift stores DateTime in seconds.
final _t0 = DateTime.utc(2026, 10, 27, 9);
final _t1 = DateTime.utc(2026, 10, 27, 9, 0, 10);
final _t2 = DateTime.utc(2026, 10, 27, 9, 0, 20);

void contract(String name, AppUsageRepository Function() make) => group(
  name,
  () {
    late AppUsageRepository repo;
    setUp(() => repo = make());

    test('record_seen_counts_and_stamps', () async {
      await repo.recordSeen('com.a.app', _t0);
      expect(await repo.watchMostUsed().first, [
        AppUsageStat(package: 'com.a.app', seenCount: 1, lastSeenAt: _t0),
      ]);
      await repo.recordSeen('com.a.app', _t2);
      final stats = await repo.watchMostUsed().first;
      expect(stats, [
        AppUsageStat(package: 'com.a.app', seenCount: 2, lastSeenAt: _t2),
      ]);
      expect(stats.single.lastSeenAt.isUtc, isTrue);
    });

    test('most_used_orders_by_count_then_recency', () async {
      await repo.recordSeen('com.once.old', _t0);
      await repo.recordSeen('com.once.new', _t2);
      await repo.recordSeen('com.twice.app', _t0);
      await repo.recordSeen('com.twice.app', _t1);
      expect(
        [for (final s in await repo.watchMostUsed().first) s.package],
        ['com.twice.app', 'com.once.new', 'com.once.old'],
      );
      expect(await repo.watchMostUsed(limit: 2).first, hasLength(2));
    });

    test('watch_follows_new_sightings', () async {
      final seen = <int>[];
      final sub = repo.watchMostUsed().listen((l) => seen.add(l.length));
      await pumpEventQueue();
      await repo.recordSeen('com.a.app', _t0);
      await pumpEventQueue();
      await repo.recordSeen('com.b.app', _t1);
      await pumpEventQueue();
      expect(seen.first, 0);
      expect(seen.last, 2);
      await sub.cancel();
    });

    test('most_used_filters_system_packages_before_the_limit', () async {
      // 30 system packages, each seen more often than any user app.
      for (var i = 0; i < 30; i++) {
        for (var n = 0; n < 3; n++) {
          await repo.recordSeen('com.mediatek.part$i', _t0);
        }
      }
      for (final app in ['com.a.app', 'com.b.app', 'com.c.app']) {
        await repo.recordSeen(app, _t1);
      }
      final stats = await repo
          .watchMostUsed(limit: 3, exclude: isSystemPackage)
          .first;
      expect(
        [for (final s in stats) s.package],
        ['com.a.app', 'com.b.app', 'com.c.app'],
      );
      // Without a filter the limit still applies to every package.
      expect(await repo.watchMostUsed(limit: 3).first, hasLength(3));
    });

    test('usage_keeps_the_200_most_recent_packages', () async {
      expect(AppUsageRepository.kUsageKeep, 200);
      // Package i is seen at second i: the first 5 are the oldest.
      for (var i = 0; i < 205; i++) {
        await repo.recordSeen(
          'com.app.n$i',
          _t0.add(Duration(seconds: i)),
        );
      }
      final kept = {
        for (final s in await repo.watchMostUsed(limit: 1000).first) s.package,
      };
      expect(kept, hasLength(200));
      expect(kept, {for (var i = 5; i < 205; i++) 'com.app.n$i'});
    });
  },
);

void main() {
  contract('drift', () {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    return DriftAppUsageRepository(db);
  });
  contract('in_memory', InMemoryAppUsageRepository.new);
}
