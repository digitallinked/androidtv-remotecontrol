import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/features/apps/data/shortcut_repository.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';

import '../../helpers/in_memory_shortcut_repository.dart';

const _a = AppEntry(package: 'com.a.app', name: 'A');
const _b = AppEntry(package: 'com.b.app', name: 'B');
const _c = AppEntry(package: 'com.c.app', name: 'C');

List<String> _packages(List<AppEntry> apps) => [
  for (final a in apps) a.package,
];

void contract(String name, ShortcutRepository Function() make) =>
    group(name, () {
      late ShortcutRepository repo;
      setUp(() => repo = make());

      test('add_appends_and_rejects_a_duplicate_package', () async {
        expect(await repo.add(_a), isTrue);
        expect(await repo.add(_b), isTrue);
        expect(
          await repo.add(const AppEntry(package: 'com.a.app', name: 'Other')),
          isFalse,
        );
        expect(await repo.all(), [_a, _b]);
        expect(await repo.count(), 2);
      });

      test('reorder_persists', () async {
        await repo.add(_a);
        await repo.add(_b);
        await repo.add(_c);
        await repo.reorder([_c.package, _a.package]);
        expect(_packages(await repo.all()), [
          'com.c.app',
          'com.a.app',
          'com.b.app',
        ]);
        // A fresh read gives the same order, unknown packages are ignored.
        await repo.reorder(['com.zzz.none', _b.package, _b.package]);
        expect(_packages(await repo.all()), [
          'com.b.app',
          'com.c.app',
          'com.a.app',
        ]);
      });

      test('replace_all_rewrites_positions_densely', () async {
        await repo.add(_a);
        await repo.add(_b);
        await repo.replaceAll([
          _c,
          _a,
          const AppEntry(package: 'com.c.app', name: 'C again'),
          _b,
        ]);
        expect(await repo.all(), [_c, _a, _b]);
        await repo.replaceAll(const []);
        expect(await repo.all(), isEmpty);
      });

      test('update_changes_name_colour_and_icon_only', () async {
        await repo.add(
          const AppEntry(
            package: 'com.a.app',
            name: 'A',
            iconUrl: 'https://example.com/a.png',
          ),
        );
        await repo.add(_b);
        await repo.update(
          const AppEntry(
            package: 'com.a.app',
            name: 'Renamed',
            launchLink: 'market://launch?id=other',
            iconUrl: 'ignored',
            isCustom: true,
            customColor: Color(0xFF2563EB),
            customIcon: 'movie',
          ),
        );
        // No shortcut with this package: nothing happens.
        await repo.update(const AppEntry(package: 'com.none.app', name: 'X'));
        final all = await repo.all();
        expect(all, hasLength(2));
        expect(all.first.name, 'Renamed');
        expect(all.first.launchLink, 'market://launch?id=other');
        expect(all.first.iconUrl, 'https://example.com/a.png');
        expect(all.first.isCustom, isTrue);
        expect(all.first.customColor, const Color(0xFF2563EB));
        expect(all.first.customIcon, 'movie');
        expect(all.last, _b);

        // The colour and icon can be cleared again.
        await repo.update(const AppEntry(package: 'com.a.app', name: 'A'));
        expect((await repo.all()).first.customColor, isNull);
        expect((await repo.all()).first.customIcon, isNull);
      });

      test('remove_deletes_one', () async {
        await repo.add(_a);
        await repo.add(_b);
        await repo.add(_c);
        await repo.remove(_b.package);
        await repo.remove('com.none.app');
        expect(await repo.all(), [_a, _c]);
        // Appending after a removal keeps the order.
        await repo.add(_b);
        expect(await repo.all(), [_a, _c, _b]);
      });

      test('custom_colour_round_trips', () async {
        const app = AppEntry(
          package: 'com.a.app',
          name: 'A',
          isCustom: true,
          customColor: Color(0xFF2563EB),
          customIcon: 'tv',
        );
        await repo.add(app);
        expect((await repo.all()).single, app);
      });

      test('watch_replays_then_follows_changes', () async {
        await repo.add(_a);
        final seen = <List<String>>[];
        final sub = repo.watchAll().listen((l) => seen.add(_packages(l)));
        await pumpEventQueue();
        expect(seen, [
          ['com.a.app'],
        ]);
        await repo.add(_b);
        await pumpEventQueue();
        await repo.reorder([_b.package]);
        await pumpEventQueue();
        expect(seen.last, ['com.b.app', 'com.a.app']);
        expect(seen.first, ['com.a.app']);
        await repo.remove(_a.package);
        await pumpEventQueue();
        expect(seen.last, ['com.b.app']);
        await sub.cancel();
      });
    });

void main() {
  contract('drift', () {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    return DriftShortcutRepository(db);
  });
  contract('in_memory', InMemoryShortcutRepository.new);

  group('drift storage', () {
    late AppDatabase db;
    late DriftShortcutRepository repo;
    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = DriftShortcutRepository(db);
    });
    tearDown(() => db.close());

    Future<List<int>> positions() async => [
      for (final r in await (db.select(
        db.shortcuts,
      )..orderBy([(t) => OrderingTerm.asc(t.position)])).get())
        r.position,
    ];

    test('positions_stay_dense_after_every_kind_of_write', () async {
      await repo.replaceAll([_a, _b, _c]);
      expect(await positions(), [0, 1, 2]);
      await repo.remove(_a.package);
      expect(await positions(), [0, 1]);
      await repo.add(_a);
      expect(await positions(), [0, 1, 2]);
      await repo.reorder([_c.package]);
      expect(await positions(), [0, 1, 2]);
      await repo.replaceAll([_b, _a]);
      expect(await positions(), [0, 1]);
    });
  });
}
