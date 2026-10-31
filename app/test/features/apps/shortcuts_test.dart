import 'dart:async';
import 'dart:io';

import 'package:atv_remote/atv_remote.dart';
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/apps/application/shortcuts.dart';
import 'package:tv_remote/features/apps/data/app_usage_repository.dart';
import 'package:tv_remote/features/apps/data/apps_data_providers.dart';
import 'package:tv_remote/features/apps/data/catalogue_repository.dart';
import 'package:tv_remote/features/apps/data/shortcut_repository.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';

import '../../helpers/fake_remote_session.dart';
import '../../helpers/in_memory_app_usage_repository.dart';
import '../../helpers/in_memory_shortcut_repository.dart';
import '../../helpers/test_catalogue.dart';

const _connected = TvConnectionState(status: ConnectionStatus.connected);
const _disconnected = TvConnectionState(status: ConnectionStatus.disconnected);

const _netflix = AppEntry(package: 'com.netflix.ninja', name: 'Netflix');

AppUsageStat _stat(String package, int count) => AppUsageStat(
  package: package,
  seenCount: count,
  lastSeenAt: DateTime.utc(2026, 10, 27, 9),
);

List<String> _packages(Iterable<AppEntry> apps) => [
  for (final a in apps) a.package,
];

void main() {
  late SettingsStore store;
  late InMemoryShortcutRepository shortcutRepo;
  late InMemoryAppUsageRepository usageRepo;
  late FakeRemoteSession session;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    store = await SettingsStore.open();
    shortcutRepo = InMemoryShortcutRepository();
    usageRepo = InMemoryAppUsageRepository();
    session = FakeRemoteSession(initial: _connected);
  });

  ProviderContainer makeContainer({
    String? region = 'MY',
    List<Override> overrides = const [],
  }) {
    final replaced = {for (final o in overrides) o.origin};
    final c =
        ProviderContainer.test(
            overrides: [
              for (final o in [
                settingsStoreProvider.overrideWithValue(store),
                shortcutRepositoryProvider.overrideWithValue(shortcutRepo),
                appUsageRepositoryProvider.overrideWithValue(usageRepo),
                catalogueProvider.overrideWith((ref) async => testCatalogue()),
                deviceRegionProvider.overrideWithValue(region),
                remoteSessionProvider.overrideWith((ref) async => session),
              ])
                if (!replaced.contains(o.origin)) o,
              ...overrides,
            ],
          )
          // An auto-dispose provider that is only read can go away mid-await.
          ..listen(shortcutsProvider, (_, _) {});
    return c;
  }

  final myRow = _packages(testCatalogue().defaultShortcutsFor('MY'));

  group('seeding', () {
    test('first_read_seeds_region_defaults_once', () async {
      final c = makeContainer();
      final first = await c.read(shortcutsProvider.future);
      expect(_packages(first), myRow);
      expect(shortcutRepo.writes, 1);
      expect(store.shortcutsSeeded, isTrue);

      // Reading again (even from a new container) writes nothing more.
      final again = makeContainer();
      await again.read(shortcutsProvider.future);
      expect(shortcutRepo.writes, 1);
      expect(_packages(shortcutRepo.apps), myRow);
    });

    test('the_star_row_seeds_when_the_region_is_unknown', () async {
      final c = makeContainer(region: null);
      final list = await c.read(shortcutsProvider.future);
      expect(
        _packages(list),
        _packages(testCatalogue().defaultShortcutsFor('*')),
      );
      expect(list.first.name, 'Netflix');
    });

    test('seeding_never_runs_again_after_the_user_empties_the_list', () async {
      final c = makeContainer();
      await c.read(shortcutsProvider.future);
      await c.read(shortcutActionsProvider).replaceAll(const []);

      final next = makeContainer();
      expect(await next.read(shortcutsProvider.future), isEmpty);
      expect(shortcutRepo.apps, isEmpty);
    });

    test('seeding_after_a_crash_mid_way_does_not_duplicate', () async {
      // The list was written, then the app died before the flag was set.
      shortcutRepo.apps.add(_netflix);
      expect(store.shortcutsSeeded, isFalse);
      final c = makeContainer();
      expect(await c.read(shortcutsProvider.future), [_netflix]);
      expect(shortcutRepo.writes, 0);
      expect(store.shortcutsSeeded, isTrue);
    });

    // On iOS the preferences come back with an iCloud restore or Quick
    // Start and the database doesn't (Ruling P8-R1): the flag then describes
    // a database that isn't there.
    test(
      'a_fresh_database_is_seeded_even_when_the_flag_was_restored',
      () async {
        await store.setShortcutsSeeded(true);
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final c = makeContainer(
          overrides: [
            shortcutRepositoryProvider.overrideWithValue(
              DriftShortcutRepository(db),
            ),
          ],
        );
        await c.read(shortcutsSeedProvider.future);
        expect(_packages(await DriftShortcutRepository(db).all()), myRow);
        expect(store.shortcutsSeeded, isTrue);
      },
    );

    test('a_database_from_an_earlier_run_keeps_an_emptied_list', () async {
      final dir = Directory.systemTemp.createTempSync('shortcuts_seed');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/remotely.sqlite');
      // The first run creates the database and seeds it; the user then
      // empties the list.
      final first = AppDatabase(NativeDatabase(file));
      final c = makeContainer(
        overrides: [
          shortcutRepositoryProvider.overrideWithValue(
            DriftShortcutRepository(first),
          ),
        ],
      );
      await c.read(shortcutsSeedProvider.future);
      await DriftShortcutRepository(first).replaceAll(const []);
      c.dispose();
      await first.close();

      // The next run opens the same file: nothing is refilled.
      final second = AppDatabase(NativeDatabase(file));
      addTearDown(second.close);
      final next = makeContainer(
        overrides: [
          shortcutRepositoryProvider.overrideWithValue(
            DriftShortcutRepository(second),
          ),
        ],
      );
      await next.read(shortcutsSeedProvider.future);
      expect(await DriftShortcutRepository(second).all(), isEmpty);
    });

    test('once_the_flag_is_set_the_seed_never_reads_the_catalogue', () async {
      await store.setShortcutsSeeded(true);
      var builds = 0;
      final c = makeContainer(
        overrides: [
          catalogueProvider.overrideWith((ref) async {
            builds++;
            throw StateError('the catalogue must not be read');
          }),
        ],
      );
      expect(await c.read(shortcutsProvider.future), isEmpty);
      await c.read(shortcutsSeedProvider.future);
      expect(builds, 0);
      expect(shortcutRepo.writes, 0);
    });

    test('seeding_never_overwrites_rows_added_while_it_waited', () async {
      // The user adds an app while the catalogue is still being read.
      final catalogue = Completer<void>();
      final c = makeContainer(
        overrides: [
          catalogueProvider.overrideWith((ref) async {
            await catalogue.future;
            return testCatalogue();
          }),
        ],
      );
      final first = c.read(shortcutsProvider.future);
      await pumpEventQueue();
      await shortcutRepo.add(_netflix);
      catalogue.complete();
      expect(await first, [_netflix]);
      expect(store.shortcutsSeeded, isTrue);
    });

    test('a_failed_seed_retries_next_time', () async {
      shortcutRepo.failNextWrite = StateError('disk full');
      final c = makeContainer();
      // It completes (no error), with nothing stored and the flag unset.
      expect(await c.read(shortcutsProvider.future), isEmpty);
      expect(store.shortcutsSeeded, isFalse);

      final next = makeContainer();
      expect(_packages(await next.read(shortcutsProvider.future)), myRow);
      expect(store.shortcutsSeeded, isTrue);
    });

    test(
      'a_corrupt_catalogue_leaves_an_empty_list_and_retries_later',
      () async {
        final c = makeContainer(
          overrides: [
            catalogueProvider.overrideWith(
              (ref) async => throw const FormatException('corrupt'),
            ),
          ],
        );
        expect(await c.read(shortcutsProvider.future), isEmpty);
        expect(store.shortcutsSeeded, isFalse);
        expect(shortcutRepo.writes, 0);
      },
    );
  });

  group('actions', () {
    test('actions_taken_before_an_await_still_write_afterwards', () async {
      // A screen that takes the actions once and awaits between two writes
      // outlives the provider: nothing else watches it here.
      final c = makeContainer();
      await c.read(shortcutsProvider.future);
      final actions = c.read(shortcutActionsProvider);
      const extra = AppEntry(package: 'com.extra.app', name: 'Extra');

      expect(await actions.add(extra), isTrue);
      await pumpEventQueue();
      expect(c.exists(shortcutActionsProvider), isFalse);
      await actions.update(
        const AppEntry(package: 'com.extra.app', name: 'Renamed'),
      );
      expect(shortcutRepo.apps.last.name, 'Renamed');
      await actions.reorder(['com.extra.app']);
      await actions.remove('com.extra.app');
      await actions.replaceAll(const [extra]);
      expect(_packages(shortcutRepo.apps), ['com.extra.app']);
      await actions.resetToDefaults();
      expect(_packages(shortcutRepo.apps), myRow);
    });

    test('reset_restores_region_defaults', () async {
      final c = makeContainer();
      await c.read(shortcutsProvider.future);
      final actions = c.read(shortcutActionsProvider);
      await actions.replaceAll(const [
        AppEntry(package: 'com.my.own', name: 'Mine', isCustom: true),
      ]);
      expect(_packages(shortcutRepo.apps), ['com.my.own']);

      await actions.resetToDefaults();
      expect(shortcutRepo.apps, testCatalogue().defaultShortcutsFor('MY'));
    });

    test('reset_reads_the_region_again', () async {
      var region = 'MY';
      final c = makeContainer(
        overrides: [deviceRegionProvider.overrideWith((ref) => region)],
      );
      await c.read(shortcutsProvider.future);
      expect(_packages(shortcutRepo.apps), myRow);

      region = 'US';
      await c.read(shortcutActionsProvider).resetToDefaults();
      expect(
        shortcutRepo.apps,
        testCatalogue().defaultShortcutsFor('US'),
      );
    });

    test(
      'add_update_remove_reorder_pass_through_and_errors_propagate',
      () async {
        final c = makeContainer();
        await c.read(shortcutsProvider.future);
        final actions = c.read(shortcutActionsProvider);
        const extra = AppEntry(package: 'com.extra.app', name: 'Extra');
        expect(await actions.add(extra), isTrue);
        expect(await actions.add(extra), isFalse);
        await actions.update(
          const AppEntry(package: 'com.extra.app', name: 'Renamed'),
        );
        expect(shortcutRepo.apps.last.name, 'Renamed');
        await actions.reorder(['com.extra.app']);
        expect(shortcutRepo.apps.first.package, 'com.extra.app');
        await actions.remove('com.extra.app');
        expect(_packages(shortcutRepo.apps), myRow);

        shortcutRepo.failNextWrite = StateError('nope');
        await expectLater(
          actions.remove('com.netflix.ninja'),
          throwsStateError,
        );
      },
    );
  });

  group('recommendations', () {
    test('recommended_apps_skip_the_list_and_system_apps', () async {
      usageRepo
        ..stats['com.netflix.ninja'] = _stat('com.netflix.ninja', 9)
        ..stats['com.example.tvapp'] = _stat('com.example.tvapp', 4)
        ..stats['android'] = _stat('android', 30);
      final c = makeContainer()..listen(recommendedAppsProvider, (_, _) {});
      final apps = await c.read(recommendedAppsProvider.future);
      // Netflix is a shortcut (MY row), `android` is a system package.
      expect(_packages(apps), ['com.example.tvapp']);
      expect(apps.single.customIcon, 'app');
    });

    test('recommended_apps_see_user_apps_behind_many_system_ones', () async {
      // More system packages than the usage limit, each seen more often.
      for (var i = 0; i < 40; i++) {
        usageRepo.stats['com.mediatek.part$i'] = _stat(
          'com.mediatek.part$i',
          50,
        );
      }
      usageRepo.stats['com.example.tvapp'] = _stat('com.example.tvapp', 1);
      final c = makeContainer()..listen(recommendedAppsProvider, (_, _) {});
      final apps = await c.read(recommendedAppsProvider.future);
      expect(_packages(apps), ['com.example.tvapp']);
    });
  });

  group('recommendation failures', () {
    test('usage_and_catalogue_both_failing_leave_no_unhandled_error', () async {
      // Seeded already, so the seed does not touch the catalogue itself.
      await store.setShortcutsSeeded(true);
      // The catalogue fails after the usage did: nothing awaits it by then.
      final catalogueFails = Completer<void>();
      final c = makeContainer(
        overrides: [
          appUsageProvider.overrideWith(
            (ref) => Stream<List<AppUsageStat>>.error(StateError('usage')),
          ),
          catalogueProvider.overrideWith((ref) async {
            await catalogueFails.future;
            throw const FormatException('corrupt');
          }),
        ],
      )..listen(recommendedAppsProvider, (_, _) {});
      await expectLater(
        c.read(recommendedAppsProvider.future),
        throwsA(isA<StateError>()),
      );
      catalogueFails.complete();
      // An unwaited failure must not surface as an unhandled error (it would
      // fail this test).
      await pumpEventQueue();
      expect(c.read(recommendedAppsProvider).hasError, isTrue);
    });
  });

  group('usage tracker', () {
    Future<ProviderContainer> trackedContainer() async {
      final c = makeContainer()
        ..listen(appUsageTrackerProvider, (_, _) {})
        ..listen(currentAppProvider, (_, _) {});
      await c.read(currentAppProvider.future);
      return c;
    }

    int seen(String package) => usageRepo.stats[package]?.seenCount ?? 0;

    test('tracker_records_each_new_foreground_app_once', () async {
      await withClock(Clock.fixed(DateTime.utc(2026, 10, 27, 9)), () async {
        await trackedContainer();
        session.push(const CurrentAppChanged('com.a.app'));
        await pumpEventQueue();
        session.push(const CurrentAppChanged('com.a.app'));
        await pumpEventQueue();
        session.push(const CurrentAppChanged('com.b.app'));
        await pumpEventQueue();
        // The connection drops and comes back on the same app.
        session.emit(_disconnected);
        await pumpEventQueue();
        session.emit(_connected);
        await pumpEventQueue();
        session.push(const CurrentAppChanged('com.b.app'));
        await pumpEventQueue();

        expect(
          {for (final e in usageRepo.stats.entries) e.key: seen(e.key)},
          {
            'com.a.app': 1,
            'com.b.app': 1,
          },
        );
        expect(
          usageRepo.stats['com.a.app']!.lastSeenAt,
          DateTime.utc(2026, 10, 27, 9),
        );
        expect(usageRepo.stats['com.a.app']!.lastSeenAt.isUtc, isTrue);
      });
    });

    test('tracker_counts_a_return_to_an_earlier_app', () async {
      await trackedContainer();
      for (final p in ['com.a.app', 'com.b.app', 'com.a.app']) {
        session.push(CurrentAppChanged(p));
        await pumpEventQueue();
      }
      expect(seen('com.a.app'), 2);
      expect(seen('com.b.app'), 1);
    });

    test('tracker_records_an_app_already_open_when_it_starts', () async {
      session.push(const CurrentAppChanged('com.a.app'));
      await trackedContainer();
      await pumpEventQueue();
      expect(seen('com.a.app'), 1);
    });

    test('tracker_ignores_the_demo_tv', () async {
      session = FakeRemoteSession(isDemo: true, initial: _connected);
      await trackedContainer();
      session.push(const CurrentAppChanged('com.netflix.ninja'));
      await pumpEventQueue();
      expect(usageRepo.stats, isEmpty);
      expect(usageRepo.writes, 0);
    });

    test('tracker_survives_a_storage_error', () async {
      await trackedContainer();
      usageRepo.failNextWrite = StateError('disk full');
      session.push(const CurrentAppChanged('com.a.app'));
      await pumpEventQueue();
      // The failed write was swallowed, and the next app still counts.
      session.push(const CurrentAppChanged('com.b.app'));
      await pumpEventQueue();
      expect(seen('com.a.app'), 0);
      expect(seen('com.b.app'), 1);
    });
  });
}
