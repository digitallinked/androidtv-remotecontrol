import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/core/crash/crash_collection.dart';
import 'package:tv_remote/core/crash/crashlytics_sink.dart';
import 'package:tv_remote/core/firebase/firebase_bootstrap.dart';
import 'package:tv_remote/core/privacy/privacy_choices.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/settings_controller.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';

import '../../helpers/fake_tv_discovery.dart';
import '../../helpers/in_memory_device_repository.dart';
import '../../helpers/recording_crashlytics_sink.dart';
import '../../helpers/test_devices.dart';

/// A repository whose saved list never arrives: `watchAll` never emits.
class _SilentDeviceRepository extends InMemoryDeviceRepository {
  final StreamController<List<SavedDevice>> _never =
      StreamController<List<SavedDevice>>.broadcast();

  @override
  Stream<List<SavedDevice>> watchAll() => _never.stream;
}

void main() {
  late RecordingCrashlyticsSink sink;
  late InMemoryDeviceRepository devices;
  late SettingsStore store;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    store = await SettingsStore.open();
    sink = RecordingCrashlyticsSink();
    devices = InMemoryDeviceRepository();
  });

  Future<ProviderContainer> containerFor({
    FirebaseStatus status = FirebaseStatus.ready,
    bool debugBuild = false,
    ConsentRegion region = ConsentRegion.notRequired,
  }) async {
    await store.setConsentRegion(region);
    return ProviderContainer.test(
      overrides: [
        settingsStoreProvider.overrideWithValue(store),
        deviceRepositoryProvider.overrideWithValue(devices),
        firebaseStatusProvider.overrideWithValue(status),
        crashlyticsSinkProvider.overrideWithValue(sink),
        crashDebugBuildProvider.overrideWithValue(debugBuild),
      ],
    );
  }

  // The app keeps the collection listened to for the container's lifetime
  // (Riverpod pauses what nothing listens to).
  CrashCollection start(ProviderContainer container) {
    container.listen(crashCollectionProvider, (_, _) {});
    return container.read(crashCollectionProvider.notifier);
  }

  // A test helper with one boolean: positional reads best.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setCrashChoice(ProviderContainer c, bool? value) => c
      .read(settingsControllerProvider.notifier)
      .update((s) => s.setShareCrashReports(value));

  // Provider updates that have listeners wait for the scheduler; `pump`
  // runs them.
  Future<void> flush(ProviderContainer container) async {
    await container.pump();
    await pumpEventQueue();
  }

  test('collection_follows_the_privacy_choice_and_region', () async {
    final container = await containerFor();
    start(container);
    await flush(container);

    expect(sink.collectionHistory, [true]);
    expect(sink.deletes, 0);

    await setCrashChoice(container, false);
    await flush(container);

    expect(sink.collectionHistory, [true, false]);
    expect(sink.deletes, 1);
  });

  test(
    'a_change_that_leaves_crash_sharing_alone_does_not_call_again',
    () async {
      final container = await containerFor();
      start(container);
      await flush(container);

      await container
          .read(settingsControllerProvider.notifier)
          .update((s) => s.setShareUsageStats(false));
      await flush(container);

      expect(sink.collectionHistory, [true]);
      expect(sink.deletes, 0);
    },
  );

  test('required_regions_stay_off_until_the_user_opts_in', () async {
    final container = await containerFor(region: ConsentRegion.required);
    start(container);
    await flush(container);
    expect(sink.collectionHistory, [false]);

    await setCrashChoice(container, true);
    await flush(container);

    expect(sink.collectionHistory, [false, true]);
    // Reports queued while the answer was a final no are deleted at startup
    // and again before sharing turns on.
    expect(sink.calls, ['delete', 'enable:false', 'delete', 'enable:true']);
  });

  test('a_final_no_at_startup_deletes_what_was_queued', () async {
    await store.setShareCrashReports(false);
    final container = await containerFor();
    start(container);
    await flush(container);

    expect(sink.calls, ['delete', 'enable:false']);
  });

  test('a_failing_delete_never_skips_the_crash_switch', () async {
    sink = RecordingCrashlyticsSink(throwOnDelete: true);
    final container = await containerFor();
    start(container);
    await flush(container);
    expect(sink.calls, ['enable:true']);

    await setCrashChoice(container, false);
    await flush(container);

    expect(sink.calls, ['enable:true', 'delete', 'enable:false']);
  });

  test('turning_sharing_back_on_deletes_reports_queued_while_off', () async {
    final container = await containerFor();
    start(container);
    await flush(container);
    await setCrashChoice(container, false);
    await flush(container);
    sink.calls.clear();

    await setCrashChoice(container, true);
    await flush(container);

    expect(sink.calls, ['delete', 'enable:true']);
  });

  test('an_undecided_start_keeps_what_was_queued', () async {
    final container = await containerFor(region: ConsentRegion.unknown);
    start(container);
    await flush(container);

    expect(sink.calls, ['enable:false']);
  });

  test('denying_after_an_unknown_region_deletes_what_was_stored', () async {
    final container = await containerFor(region: ConsentRegion.unknown);
    start(container);
    await flush(container);
    expect(sink.collectionHistory, [false]);

    await setCrashChoice(container, false);
    await flush(container);

    expect(sink.collectionHistory, [false]);
    expect(sink.deletes, 1);
  });

  test('the_region_becoming_known_applies_at_once', () async {
    final container = await containerFor(region: ConsentRegion.unknown);
    start(container);
    await flush(container);

    await container
        .read(consentRegionStateProvider.notifier)
        .set(ConsentRegion.notRequired);
    await flush(container);

    expect(sink.collectionHistory, [false, true]);
  });

  test('debug_builds_keep_native_collection_off', () async {
    final container = await containerFor(debugBuild: true);
    start(container);
    await flush(container);

    expect(sink.collectionHistory, [false]);
    expect(sink.deletes, 0);
  });

  test('saved_tv_names_reach_the_scrubber', () async {
    final container = await containerFor();
    final collection = start(container);
    await flush(container);

    await devices.upsert(savedTv(name: 'Den', nickname: "Dad's Telly"));
    await flush(container);

    expect(collection.scrubber.scrub('Den'), '<tv>');
    expect(collection.scrubber.scrub("Dad's Telly is off"), '<tv> is off');

    await collection.reporter.recordError(StateError('Den up'), null);
    expect(
      sink.errors.single.error.toString(),
      'StateError: Bad state: <tv> up',
    );
  });

  test('the_scrubber_follows_removed_tvs', () async {
    final container = await containerFor();
    final collection = start(container);
    await devices.upsert(savedTv(name: 'Den'));
    await flush(container);
    expect(collection.scrubber.scrub('Den'), '<tv>');

    await devices.delete('Den');
    await flush(container);

    expect(collection.scrubber.scrub('Den'), 'Den');
  });

  test('saved_names_are_scrubbed_before_the_first_watch_event', () async {
    devices = _SilentDeviceRepository();
    final container = await containerFor();
    final collection = start(container)
      ..seedTerms([
        savedTv(name: 'Bedroom TV', nickname: 'Big screen'),
        SavedDevice(
          serviceName: 'Android TV 4B2F',
          displayName: 'Lounge',
          lastHost: '192.168.0.21',
          port: 6466,
          lastConnectedAt: DateTime.utc(2026, 10, 25),
        ),
      ]);
    await flush(container);

    await collection.reporter.recordError(
      StateError('lost Bedroom TV, Big screen, Lounge, Android TV 4B2F'),
      null,
    );

    final sent = sink.errors.single.error.toString();
    expect(sent, isNot(contains('Bedroom TV')));
    expect(sent, isNot(contains('Big screen')));
    expect(sent, isNot(contains('Lounge')));
    expect(sent, isNot(contains('4B2F')));
  });

  test('the_first_watch_event_replaces_the_seeded_names', () async {
    final container = await containerFor();
    final collection = start(container)..seedTerms([savedTv(name: 'Den')]);
    await flush(container);
    // The repository is empty: its first list has no Den, so the seed goes.
    expect(collection.scrubber.scrub('Den'), 'Den');

    collection.seedTerms([savedTv(name: 'Attic')]);
    expect(collection.scrubber.scrub('Attic'), '<tv>');
    await devices.upsert(savedTv(name: 'Den'));
    await flush(container);
    expect(collection.scrubber.scrub('Den'), '<tv>');
    expect(collection.scrubber.scrub('Attic'), 'Attic');
  });

  test('discovered_unsaved_names_are_scrubbed', () async {
    final container = await containerFor();
    final collection = start(container);
    await flush(container);

    collection.addDiscoveredTerms([
      const DiscoveredTv(
        serviceName: 'Kitchen TV (2)',
        displayName: 'Kitchen TV',
        host: '192.168.0.30',
        port: 6466,
        isLegacyService: false,
      ),
    ]);
    await collection.reporter.recordError(
      StateError('pairing Kitchen TV failed for Kitchen TV (2)'),
      null,
    );

    final sent = sink.errors.single.error.toString();
    expect(sent, isNot(contains('Kitchen')));
    expect(sent, 'StateError: Bad state: pairing <tv> failed for <tv>');
  });

  test('discovered_terms_survive_a_saved_list_change_and_cap_at_64', () async {
    final container = await containerFor();
    final collection = start(container);
    await flush(container);

    collection.addDiscoveredTerms([tv('Kitchen TV')]);
    await devices.upsert(savedTv(name: 'Den'));
    await flush(container);
    await devices.delete('Den');
    await flush(container);
    expect(collection.scrubber.scrub('Kitchen TV'), '<tv>');
    expect(collection.scrubber.scrub('Den'), 'Den');

    DiscoveredTv numbered(int i) => DiscoveredTv(
      serviceName: 'Service $i',
      displayName: 'Shown $i',
      host: '192.168.0.40',
      port: 6466,
      isLegacyService: false,
    );

    // 63 more TVs make 64: every one is kept, both of its names.
    collection.addDiscoveredTerms([for (var i = 0; i < 63; i++) numbered(i)]);
    expect(collection.scrubber.scrub('Kitchen TV'), '<tv>');
    expect(collection.scrubber.scrub('Shown 0'), '<tv>');
    expect(collection.scrubber.scrub('Service 0'), '<tv>');

    // A 65th TV, in a later list: the oldest TV, Kitchen TV, goes.
    collection.addDiscoveredTerms([tv('Porch')]);
    expect(collection.scrubber.scrub('Kitchen TV'), 'Kitchen TV');
    expect(collection.scrubber.scrub('Porch'), '<tv>');

    // Seeing a TV again makes it the newest, so it outlives older ones.
    collection
      ..addDiscoveredTerms([numbered(0)])
      ..addDiscoveredTerms([tv('Garage')]);
    expect(collection.scrubber.scrub('Shown 0'), '<tv>');
    expect(collection.scrubber.scrub('Service 0'), '<tv>');
    expect(collection.scrubber.scrub('Shown 1'), 'Shown 1');
    expect(collection.scrubber.scrub('Service 1'), 'Service 1');
  });

  test('a_busy_network_never_evicts_the_tvs_of_the_latest_list', () async {
    final container = await containerFor();
    final collection = start(container);
    await flush(container);

    DiscoveredTv numbered(int i) => DiscoveredTv(
      serviceName: 'Service $i',
      displayName: 'Shown $i',
      host: '192.168.0.40',
      port: 6466,
      isLegacyService: false,
    );

    // A hotel network: 100 TVs in one list, the one being paired first.
    collection.addDiscoveredTerms([
      tv('Room 101 TV'),
      for (var i = 0; i < 99; i++) numbered(i),
    ]);
    expect(collection.scrubber.scrub('Room 101 TV'), '<tv>');
    expect(collection.scrubber.scrub('Shown 98'), '<tv>');

    // The next list still holds it: it stays, while older TVs not in the
    // list make room.
    collection.addDiscoveredTerms([tv('Room 101 TV')]);
    expect(collection.scrubber.scrub('Room 101 TV'), '<tv>');
    expect(collection.scrubber.scrub('Shown 0'), 'Shown 0');
    expect(collection.scrubber.scrub('Shown 98'), '<tv>');
  });

  test('a_failing_device_list_is_ignored', () async {
    devices.watchError = StateError('db is gone');
    final container = await containerFor();
    final collection = start(container);
    await flush(container);

    expect(collection.scrubber.scrub('x 10.0.0.1'), 'x <ip>');
    expect(sink.collectionHistory, [true]);
  });

  test('firebase_not_ready_never_touches_the_sink', () async {
    for (final status in [
      FirebaseStatus.notConfigured,
      FirebaseStatus.unavailable,
    ]) {
      final container = await containerFor(status: status);
      final collection = start(container);
      await flush(container);
      await collection.reporter.recordError('x', null);
      await setCrashChoice(container, false);
      await flush(container);

      expect(sink.untouched, isTrue);
    }
  });

  test('the_reporter_sends_while_allowed_and_stops_when_turned_off', () async {
    final container = await containerFor();
    final reporter = start(container).reporter;
    await flush(container);

    await reporter.recordError('first', null);
    await setCrashChoice(container, false);
    await flush(container);
    await reporter.recordError('second', null);

    expect(sink.errors.map((e) => e.error.toString()), ['String: first']);
  });

  test('debug_builds_send_nothing_through_the_reporter', () async {
    final container = await containerFor(debugBuild: true);
    final reporter = start(container).reporter;
    await flush(container);

    await reporter.recordError('x', null);

    expect(sink.errors, isEmpty);
  });

  test('the_default_sink_is_the_firebase_one', () {
    final container = ProviderContainer.test();
    expect(container.read(crashlyticsSinkProvider), isA<CrashlyticsSink>());
  });
}
