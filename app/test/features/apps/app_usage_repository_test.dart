import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/features/apps/data/app_usage_repository.dart';

import '../../helpers/in_memory_app_usage_repository.dart';

// Whole seconds: drift stores DateTime in seconds.
final _t0 = DateTime.utc(2026, 10, 27, 9);
final _t1 = DateTime.utc(2026, 10, 27, 9, 0, 10);
final _t2 = DateTime.utc(2026, 10, 27, 9, 0, 20);

void contract(String name, AppUsageRepository Function() make) =>
    group(name, () {
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
    });

void main() {
  contract('drift', () {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    return DriftAppUsageRepository(db);
  });
  contract('in_memory', InMemoryAppUsageRepository.new);
}
