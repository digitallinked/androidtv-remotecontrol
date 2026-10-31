import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/app/flavor.dart';
import 'package:tv_remote/bootstrap.dart';
import 'package:tv_remote/core/app_info/app_info.dart';
import 'package:tv_remote/core/config/app_config.dart';
import 'package:tv_remote/core/config/service_config.dart';
import 'package:tv_remote/core/config/update_gate.dart';
import 'package:tv_remote/core/crash/crash_collection.dart';
import 'package:tv_remote/core/crash/crash_reporter.dart';
import 'package:tv_remote/core/firebase/firebase_bootstrap.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';

import 'helpers/fake_ads_overrides.dart';
import 'helpers/fake_config_source.dart';
import 'helpers/in_memory_device_repository.dart';
import 'helpers/recording_crash_reporter.dart';
import 'helpers/recording_crashlytics_sink.dart';
import 'helpers/test_devices.dart';

/// Holds saved TVs whose list stream never emits, and reports no last-used
/// TV, so the app opens on onboarding.
class _SilentDeviceRepository extends InMemoryDeviceRepository {
  _SilentDeviceRepository(super.initial);

  final StreamController<List<SavedDevice>> _never =
      StreamController<List<SavedDevice>>.broadcast();

  @override
  Stream<List<SavedDevice>> watchAll() => _never.stream;

  @override
  Future<SavedDevice?> lastUsed() async => null;
}

/// A repository whose one-shot read fails.
class _UnreadableDeviceRepository extends _SilentDeviceRepository {
  _UnreadableDeviceRepository() : super(const []);

  @override
  Future<List<SavedDevice>> all() async => throw StateError('db is gone');
}

/// A late repository whose one-shot read throws before it returns a future.
class _ThrowingLateDeviceRepository extends _LateDeviceRepository {
  @override
  Future<List<SavedDevice>> all() => throw StateError('db is gone');
}

/// A repository whose one-shot read never answers.
class _HangingDeviceRepository extends _SilentDeviceRepository {
  _HangingDeviceRepository() : super(const []);

  @override
  Future<List<SavedDevice>> all() => Completer<List<SavedDevice>>().future;
}

/// A repository whose one-shot read and saved-list stream answer only when
/// the test says so, and which reports no last-used TV.
class _LateDeviceRepository extends InMemoryDeviceRepository {
  _LateDeviceRepository() : super(const []);

  /// Completes the one-shot read.
  final Completer<List<SavedDevice>> read = Completer<List<SavedDevice>>();

  /// Emits the saved lists.
  final StreamController<List<SavedDevice>> lists =
      StreamController<List<SavedDevice>>.broadcast();

  @override
  Future<List<SavedDevice>> all() => read.future;

  @override
  Stream<List<SavedDevice>> watchAll() => lists.stream;

  @override
  Future<SavedDevice?> lastUsed() async => null;
}

/// A late repository whose one-shot read fails at once.
class _UnreadableLateDeviceRepository extends _LateDeviceRepository {
  @override
  Future<List<SavedDevice>> all() async => throw StateError('db is gone');
}

void main() {
  testWidgets('failing_step_is_reported_and_later_steps_run', (tester) async {
    final recorder = RecordingCrashReporter();
    var ran = false;

    await runStartupSteps([
      () async => throw StateError('boom'),
      () async => ran = true,
    ], reporter: recorder);

    expect(ran, isTrue);
    expect(recorder.errors.single.fatal, isFalse);
    expect(recorder.errors.single.reason, 'startup step 0');
  });

  testWidgets('hanging_step_times_out_after_5s', (tester) async {
    var done = false;
    final r = RecordingCrashReporter();
    unawaited(
      runStartupSteps([
        () => Completer<void>().future,
      ], reporter: r).then((_) => done = true),
    );

    await tester.pump(const Duration(seconds: 4));
    expect(done, isFalse);
    await tester.pump(const Duration(seconds: 2));
    expect(done, isTrue);
    expect(r.errors, hasLength(1));
    expect(r.errors.single.fatal, isFalse);
  });

  testWidgets('reporter_failure_does_not_stop_startup', (tester) async {
    var ran = false;

    await runStartupSteps([
      () async => throw StateError('boom'),
      () async => ran = true,
    ], reporter: RecordingCrashReporter(throwOnRecord: true));

    expect(ran, isTrue);
  });

  group('StartupGate', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    Widget gate(
      RecordingCrashReporter reporter, {
      Future<SettingsStore> Function() openSettings = SettingsStore.open,
      AppDatabase Function()? openDatabase,
    }) => StartupGate(
      reporter: reporter,
      build: () => buildRootWidget(
        flavor: Flavor.dev,
        crashReporter: reporter,
        openSettings: openSettings,
        openDatabase:
            openDatabase ?? () => AppDatabase(NativeDatabase.memory()),
        overrides: fakeAdsOverrides(),
      ),
    );

    Future<void> expectErrorThenRetrySucceeds(
      WidgetTester tester,
      RecordingCrashReporter reporter,
      void Function() fixFailure, {
      bool retryWithSemantics = false,
    }) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpAndSettle();

      expect(find.text('The app could not start'), findsOneWidget);
      expect(find.text('Find your TV'), findsNothing);
      expect(reporter.errors, hasLength(1));
      expect(reporter.errors.single.fatal, isTrue);
      expect(
        tester.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(48),
      );
      expect(find.bySemanticsLabel('Try again'), findsOneWidget);
      final node = tester.getSemantics(find.bySemanticsLabel('Try again'));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

      fixFailure();
      if (retryWithSemantics) {
        tester.semantics.tap(find.semantics.byLabel('Try again'));
      } else {
        await tester.tap(find.text('Try again'));
      }
      await tester.pumpAndSettle();

      expect(find.text('The app could not start'), findsNothing);
      expect(find.text('Find your TV'), findsOneWidget);
      expect(reporter.errors, hasLength(1));
      semantics.dispose();
    }

    testWidgets('settings_failure_shows_error_screen_and_retry_recovers', (
      tester,
    ) async {
      final reporter = RecordingCrashReporter();
      var broken = true;
      await tester.pumpWidget(
        gate(
          reporter,
          openSettings: () async {
            if (broken) throw StateError('prefs are unreadable');
            return SettingsStore.open();
          },
        ),
      );

      await expectErrorThenRetrySucceeds(tester, reporter, () {
        broken = false;
      });
    });

    testWidgets('database_failure_shows_error_screen_and_retry_recovers', (
      tester,
    ) async {
      final reporter = RecordingCrashReporter();
      var broken = true;
      await tester.pumpWidget(
        gate(
          reporter,
          openDatabase: () {
            if (broken) throw StateError('database is locked');
            return AppDatabase(NativeDatabase.memory());
          },
        ),
      );

      await expectErrorThenRetrySucceeds(tester, reporter, () {
        broken = false;
      }, retryWithSemantics: true);
    });

    testWidgets('two_rapid_retries_open_only_one_database', (tester) async {
      final reporter = RecordingCrashReporter();
      var opens = 0;
      await tester.pumpWidget(
        gate(
          reporter,
          openDatabase: () {
            opens++;
            if (opens == 1) throw StateError('database is locked');
            return AppDatabase(NativeDatabase.memory());
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(opens, 1);

      final retry = tester.widget<FilledButton>(find.byType(FilledButton));
      retry.onPressed!();
      retry.onPressed!();
      await tester.pumpAndSettle();

      expect(opens, 2);
      expect(find.text('Find your TV'), findsOneWidget);
    });
  });
  group('Firebase startup', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    Future<Widget> root(
      RecordingCrashReporter reporter,
      Future<FirebaseStatus> Function(ServiceConfig) initFirebase, {
      List<StartupStep> startupSteps = const [],
    }) => buildRootWidget(
      flavor: Flavor.dev,
      crashReporter: reporter,
      serviceConfig: const ServiceConfig(firebaseEnabled: true),
      initFirebase: initFirebase,
      startupSteps: startupSteps,
      openDatabase: () => AppDatabase(NativeDatabase.memory()),
      overrides: fakeAdsOverrides(),
    );

    ProviderContainer containerOf(WidgetTester tester) => tester
        .widget<UncontrolledProviderScope>(
          find.byType(UncontrolledProviderScope),
        )
        .container;

    testWidgets('app_starts_when_firebase_init_fails', (tester) async {
      final rec = RecordingCrashReporter();

      final app = await root(rec, (_) async => throw StateError('no config'));
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      expect(find.text('Find your TV'), findsOneWidget);
      expect(
        containerOf(tester).read(firebaseStatusProvider),
        FirebaseStatus.unavailable,
      );
      expect(rec.errors.single.reason, 'startup step 0');
      expect(rec.errors.single.fatal, isFalse);
    });

    testWidgets('firebase_status_reaches_the_providers', (tester) async {
      final rec = RecordingCrashReporter();
      ServiceConfig? seen;

      final app = await root(rec, (config) async {
        seen = config;
        return FirebaseStatus.ready;
      });
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      final container = containerOf(tester);
      expect(container.read(firebaseStatusProvider), FirebaseStatus.ready);
      expect(container.read(serviceConfigProvider).firebaseEnabled, isTrue);
      expect(seen?.firebaseEnabled, isTrue);
      expect(rec.errors, isEmpty);
    });

    testWidgets('firebase_is_the_first_startup_step', (tester) async {
      final order = <String>[];

      await root(RecordingCrashReporter(), (_) async {
        order.add('firebase');
        return FirebaseStatus.ready;
      }, startupSteps: [() async => order.add('later')]);

      expect(order, ['firebase', 'later']);
    });

    testWidgets('a_hanging_firebase_init_does_not_block_the_first_frame', (
      tester,
    ) async {
      final rec = RecordingCrashReporter();
      Widget? app;
      unawaited(
        root(
          rec,
          (_) => Completer<FirebaseStatus>().future,
        ).then((w) => app = w),
      );

      await tester.pump(const Duration(seconds: 6));
      expect(app, isNotNull);
      expect(rec.errors.single.reason, 'startup step 0');

      await tester.pumpWidget(app!);
      await tester.pumpAndSettle();
      expect(find.text('Find your TV'), findsOneWidget);
      expect(
        containerOf(tester).read(firebaseStatusProvider),
        FirebaseStatus.unavailable,
      );
    });

    testWidgets('startup_that_never_finishes_shows_the_error_screen', (
      tester,
    ) async {
      final rec = RecordingCrashReporter();
      final slow = Completer<Widget>();
      var builds = 0;
      await tester.pumpWidget(
        StartupGate(
          reporter: rec,
          timeout: const Duration(seconds: 1),
          build: () {
            builds++;
            return slow.future;
          },
        ),
      );

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(find.text('The app could not start'), findsOneWidget);
      expect(rec.errors.single.fatal, isTrue);
      expect(rec.errors.single.reason, 'startup timeout');

      // Still running: Try again waits for it (and times out again) rather
      // than starting a second build.
      await tester.tap(find.text('Try again'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('The app could not start'), findsOneWidget);
      expect(rec.errors.map((e) => e.reason), [
        'startup timeout',
        'startup timeout',
      ]);

      // Once it finishes, Try again shows the app.
      slow.complete(await root(rec, (_) async => FirebaseStatus.notConfigured));
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('The app could not start'), findsNothing);
      expect(find.text('Find your TV'), findsOneWidget);
      expect(builds, 1);
    });

    testWidgets(
      'a_build_that_fails_after_its_timeout_is_retried_on_the_first_tap',
      (tester) async {
        final rec = RecordingCrashReporter();
        final first = Completer<Widget>();
        var builds = 0;
        await tester.pumpWidget(
          StartupGate(
            reporter: rec,
            build: () {
              builds++;
              if (builds == 1) return first.future;
              return root(rec, (_) async => FirebaseStatus.notConfigured);
            },
          ),
        );

        await tester.pump(const Duration(seconds: 20));
        await tester.pump();
        expect(find.text('The app could not start'), findsOneWidget);

        // The first build fails after the gate gave up on it.
        first.completeError(StateError('late failure'));
        await tester.pump();

        // One tap starts a fresh build instead of re-reporting the old failure.
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();

        expect(builds, 2);
        expect(find.text('The app could not start'), findsNothing);
        expect(find.text('Find your TV'), findsOneWidget);
      },
    );

    testWidgets('try_again_after_a_timeout_reuses_the_build_still_running', (
      tester,
    ) async {
      final rec = RecordingCrashReporter();
      var builds = 0;
      var opens = 0;
      await tester.pumpWidget(
        StartupGate(
          reporter: rec,
          timeout: const Duration(seconds: 1),
          build: () {
            builds++;
            // The Firebase step hangs until its own 5 s timeout.
            return buildRootWidget(
              flavor: Flavor.dev,
              crashReporter: rec,
              initFirebase: (_) => Completer<FirebaseStatus>().future,
              openDatabase: () {
                opens++;
                return AppDatabase(NativeDatabase.memory());
              },
              overrides: fakeAdsOverrides(),
            );
          },
        ),
      );

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('The app could not start'), findsOneWidget);
      expect(rec.errors.first.reason, 'startup timeout');

      // The first build finishes after the gate gave up on it.
      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Find your TV'), findsOneWidget);
      expect(builds, 1);
      expect(opens, 1);
    });
  });

  group('Remote Config startup', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    Future<Widget> root(
      RecordingCrashReporter reporter,
      FakeConfigSource source, {
      List<StartupStep> startupSteps = const [],
    }) => buildRootWidget(
      flavor: Flavor.dev,
      crashReporter: reporter,
      startupSteps: startupSteps,
      openDatabase: () => AppDatabase(NativeDatabase.memory()),
      overrides: [
        ...fakeAdsOverrides(),
        remoteConfigSourceProvider.overrideWithValue(source),
        appInfoProvider.overrideWith(
          (ref) async => const AppInfo(
            appName: 'Remotely Dev',
            version: '1.0.0',
            buildNumber: '1',
            os: 'Android',
            osVersion: '12',
          ),
        ),
      ],
    );

    ProviderContainer containerOf(WidgetTester tester) => tester
        .widget<UncontrolledProviderScope>(
          find.byType(UncontrolledProviderScope),
        )
        .container;

    testWidgets('config_is_activated_before_the_first_frame', (tester) async {
      final rec = RecordingCrashReporter();
      final source = FakeConfigSource(
        {'min_supported_version': '2.0.0', 'ads_banner_enabled': false},
        fetched: {'min_supported_version': '3.0.0'},
      );

      await tester.pumpWidget(await root(rec, source));
      await tester.pumpAndSettle();

      final config = containerOf(tester).read(appConfigProvider);
      expect(config.minSupportedVersion, '2.0.0');
      expect(config.adsBannerEnabled, isFalse);
      // The download was started for the next launch only.
      expect(source.calls, ['activateCached', 'fetchForNextLaunch']);
      expect(rec.errors, isEmpty);
    });

    testWidgets('config_never_blocks_startup', (tester) async {
      final rec = RecordingCrashReporter();
      final source = FakeConfigSource(
        {'min_supported_version': '9.0.0'},
        activateBlock: Completer<void>().future,
      );
      Widget? app;
      unawaited(root(rec, source).then((w) => app = w));

      await tester.pump(const Duration(seconds: 4));
      expect(app, isNull);
      await tester.pump(const Duration(seconds: 2));
      expect(app, isNotNull);
      // The slow step is reported as the one after Firebase (step 0).
      expect(rec.errors.single.reason, 'startup step 1');
      expect(rec.errors.single.fatal, isFalse);

      await tester.pumpWidget(app!);
      await tester.pumpAndSettle();
      expect(find.text('Find your TV'), findsOneWidget);
      expect(
        containerOf(tester).read(appConfigProvider),
        AppConfigValues.defaults,
      );
    });

    testWidgets('a_config_that_activates_after_the_bound_changes_nothing', (
      tester,
    ) async {
      final rec = RecordingCrashReporter();
      final slow = Completer<void>();
      final source = FakeConfigSource(
        {'min_supported_version': '9.0.0', 'ads_banner_enabled': false},
        activateBlock: slow.future,
      );
      Widget? app;
      unawaited(root(rec, source).then((w) => app = w));
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpWidget(app!);
      await tester.pumpAndSettle();

      // The platform answers at 7 s, well into the session.
      await tester.pump(const Duration(seconds: 1));
      slow.complete();
      await tester.pumpAndSettle();

      final container = containerOf(tester);
      expect(container.read(appConfigProvider), AppConfigValues.defaults);
      expect(container.read(updateRequiredProvider), isFalse);
      expect(find.text('Find your TV'), findsOneWidget);
      expect(find.text('Update required'), findsNothing);
    });

    testWidgets('a_failing_config_source_starts_the_app_on_defaults', (
      tester,
    ) async {
      final rec = RecordingCrashReporter();
      final source = FakeConfigSource(
        const {},
        activateError: StateError('no play services'),
      );

      await tester.pumpWidget(await root(rec, source));
      await tester.pumpAndSettle();

      expect(find.text('Find your TV'), findsOneWidget);
      expect(
        containerOf(tester).read(appConfigProvider),
        AppConfigValues.defaults,
      );
    });

    testWidgets('config_runs_after_firebase_and_the_passed_steps', (
      tester,
    ) async {
      final order = <String>[];
      final source = _OrderSource(order);

      await root(
        RecordingCrashReporter(),
        source,
        startupSteps: [() async => order.add('step')],
      );

      expect(order, ['step', 'activateCached', 'fetchForNextLaunch']);
    });

    testWidgets('without_firebase_the_app_runs_on_defaults', (tester) async {
      final app = await buildRootWidget(
        flavor: Flavor.dev,
        crashReporter: RecordingCrashReporter(),
        openDatabase: () => AppDatabase(NativeDatabase.memory()),
        overrides: fakeAdsOverrides(),
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      final container = containerOf(tester);
      expect(
        container.read(remoteConfigSourceProvider),
        isA<DefaultsOnlyConfigSource>(),
      );
      expect(container.read(appConfigProvider), AppConfigValues.defaults);
    });
  });

  group('Launch count', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    Future<Widget> root({
      RecordingCrashReporter? reporter,
      Future<SettingsStore> Function() openSettings = SettingsStore.open,
    }) => buildRootWidget(
      flavor: Flavor.dev,
      crashReporter: reporter ?? RecordingCrashReporter(),
      openSettings: openSettings,
      openDatabase: () => AppDatabase(NativeDatabase.memory()),
      overrides: fakeAdsOverrides(),
    );

    Future<int> storedLaunchCount() async =>
        (await SettingsStore.open()).launchCount;

    testWidgets('launch_count_increments_once_per_start', (tester) async {
      await tester.pumpWidget(await root());
      await tester.pumpAndSettle();
      expect(await storedLaunchCount(), 1);

      // Frames, rebuilds and settings changes are not launches.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(await storedLaunchCount(), 1);

      // The next start.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(await root());
      await tester.pumpAndSettle();
      expect(await storedLaunchCount(), 2);
    });

    testWidgets('try_again_after_a_failed_start_counts_one_launch', (
      tester,
    ) async {
      final reporter = RecordingCrashReporter();
      var broken = true;
      await tester.pumpWidget(
        StartupGate(
          reporter: reporter,
          build: () => buildRootWidget(
            flavor: Flavor.dev,
            crashReporter: reporter,
            // The first start fails while it resolves the first screen.
            openDatabase: () {
              if (broken) throw StateError('database is locked');
              return AppDatabase(NativeDatabase.memory());
            },
            overrides: fakeAdsOverrides(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('The app could not start'), findsOneWidget);
      expect(await storedLaunchCount(), 0);

      broken = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Find your TV'), findsOneWidget);
      expect(await storedLaunchCount(), 1);
    });

    testWidgets(
      'a_launch_count_write_that_never_finishes_does_not_hold_startup',
      (
        tester,
      ) async {
        Widget? app;
        unawaited(
          root(
            openSettings: () async => _StuckLaunchCountStore(
              await SharedPreferencesWithCache.create(
                cacheOptions: const SharedPreferencesWithCacheOptions(
                  allowList: SettingsStore.keys,
                ),
              ),
            ),
          ).then((w) => app = w),
        );
        await tester.pump(const Duration(seconds: 1));
        expect(app, isNotNull, reason: 'startup does not wait for the write');

        await tester.pumpWidget(app!);
        await tester.pumpAndSettle();
        expect(find.text('Find your TV'), findsOneWidget);
      },
    );

    testWidgets('a_launch_count_that_cannot_be_written_does_not_stop_startup', (
      tester,
    ) async {
      final reporter = RecordingCrashReporter();
      await tester.pumpWidget(
        await root(
          reporter: reporter,
          openSettings: () async => _NoLaunchCountStore(
            await SharedPreferencesWithCache.create(
              cacheOptions: const SharedPreferencesWithCacheOptions(
                allowList: SettingsStore.keys,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Find your TV'), findsOneWidget);
      expect(reporter.errors.single.reason, 'launch count');
      expect(reporter.errors.single.fatal, isFalse);
    });
  });

  group('Crashlytics reporter', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    Future<Widget> root(
      CrashReporter reporter,
      RecordingCrashlyticsSink sink,
      FirebaseStatus status,
    ) => buildRootWidget(
      flavor: Flavor.dev,
      crashReporter: reporter,
      serviceConfig: const ServiceConfig(firebaseEnabled: true),
      initFirebase: (_) async => status,
      // A region where sharing is on, so a report would be sent.
      openSettings: () async {
        final store = await SettingsStore.open();
        await store.setConsentRegion(ConsentRegion.notRequired);
        return store;
      },
      openDatabase: () => AppDatabase(NativeDatabase.memory()),
      overrides: [
        ...fakeAdsOverrides(),
        crashlyticsSinkProvider.overrideWithValue(sink),
        crashDebugBuildProvider.overrideWithValue(false),
        deviceRepositoryProvider.overrideWithValue(InMemoryDeviceRepository()),
      ],
    );

    testWidgets('firebase_ready_installs_the_scrubbing_reporter', (
      tester,
    ) async {
      final logging = RecordingCrashReporter();
      final reporter = DelegatingCrashReporter(logging);
      final sink = RecordingCrashlyticsSink();

      await tester.pumpWidget(await root(reporter, sink, FirebaseStatus.ready));
      await tester.pumpAndSettle();

      expect(reporter.delegate, isA<CompositeCrashReporter>());
      await reporter.recordError(
        StateError('lost 192.168.0.20'),
        null,
        fatal: true,
      );
      // The sink sees scrubbed text; the log-only reporter is still wired.
      expect(
        sink.errors.single.error.toString(),
        'StateError: Bad state: lost <ip>',
      );
      expect(sink.errors.single.fatal, isTrue);
      expect(sink.collectionHistory, [true]);
    });

    for (final status in [
      FirebaseStatus.unavailable,
      FirebaseStatus.notConfigured,
    ]) {
      testWidgets('firebase_${status.name}_keeps_logging_only', (
        tester,
      ) async {
        final logging = RecordingCrashReporter();
        final reporter = DelegatingCrashReporter(logging);
        final sink = RecordingCrashlyticsSink();

        await tester.pumpWidget(await root(reporter, sink, status));
        await tester.pumpAndSettle();

        expect(reporter.delegate, same(logging));
        await reporter.recordError('x', null);
        expect(logging.errors, hasLength(1));
        expect(sink.untouched, isTrue);
      });
    }

    Future<Widget> rootWith(
      CrashReporter reporter,
      RecordingCrashlyticsSink sink,
      InMemoryDeviceRepository devices,
    ) => buildRootWidget(
      flavor: Flavor.dev,
      crashReporter: reporter,
      serviceConfig: const ServiceConfig(firebaseEnabled: true),
      initFirebase: (_) async => FirebaseStatus.ready,
      openSettings: () async {
        final store = await SettingsStore.open();
        await store.setConsentRegion(ConsentRegion.notRequired);
        return store;
      },
      openDatabase: () => AppDatabase(NativeDatabase.memory()),
      overrides: [
        ...fakeAdsOverrides(),
        crashlyticsSinkProvider.overrideWithValue(sink),
        crashDebugBuildProvider.overrideWithValue(false),
        deviceRepositoryProvider.overrideWithValue(devices),
      ],
    );

    testWidgets('bootstrap_seeds_scrub_terms_before_run_app', (tester) async {
      final reporter = DelegatingCrashReporter(RecordingCrashReporter());
      final sink = RecordingCrashlyticsSink();
      // The saved list stream never emits: only the seed can know the name.
      final devices = _SilentDeviceRepository([
        savedTv(name: 'Bedroom TV', nickname: 'Big screen'),
      ]);

      final app = await rootWith(reporter, sink, devices);
      // Before the first frame: an error now must already be scrubbed.
      await reporter.recordError(
        StateError('lost Bedroom TV (Big screen)'),
        null,
      );
      expect(
        sink.errors.single.error.toString(),
        'StateError: Bad state: lost <tv> (<tv>)',
      );

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
    });

    testWidgets('an_unreadable_saved_list_seeds_nothing_and_starts', (
      tester,
    ) async {
      final logging = RecordingCrashReporter();
      final reporter = DelegatingCrashReporter(logging);
      final sink = RecordingCrashlyticsSink();

      final app = await rootWith(reporter, sink, _UnreadableDeviceRepository());
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // The saved names are unknown (Ruling P8-C11): logged only, never sent,
      // while native collection still follows the choice.
      expect(reporter.delegate, isNot(isA<CompositeCrashReporter>()));
      await reporter.recordError(StateError('lost Bedroom TV'), null);
      expect(sink.errors, isEmpty);
      expect(logging.errors, hasLength(1));
      expect(sink.collectionHistory, [true]);
    });

    testWidgets(
      'a_failed_seed_read_sends_nothing_until_the_saved_list_arrives',
      (
        tester,
      ) async {
        final reporter = DelegatingCrashReporter(RecordingCrashReporter());
        final sink = RecordingCrashlyticsSink();
        final devices = _UnreadableLateDeviceRepository();
        await tester.pumpWidget(await rootWith(reporter, sink, devices));
        await tester.pump();

        await reporter.recordError(StateError('lost Bedroom TV'), null);
        expect(sink.errors, isEmpty);

        devices.lists.add([savedTv(name: 'Bedroom TV')]);
        await tester.pump();

        expect(reporter.delegate, isA<CompositeCrashReporter>());
        await reporter.recordError(StateError('lost Bedroom TV'), null);
        expect(
          sink.errors.single.error.toString(),
          'StateError: Bad state: lost <tv>',
        );
        await tester.pumpAndSettle();
      },
    );

    testWidgets('a_seed_read_that_throws_at_once_holds_reports_and_starts', (
      tester,
    ) async {
      final logging = RecordingCrashReporter();
      final reporter = DelegatingCrashReporter(logging);
      final sink = RecordingCrashlyticsSink();
      final devices = _ThrowingLateDeviceRepository();
      // A synchronous throw is a failed read like any other: the start goes
      // on, and reports are held until the saved names are known.
      await tester.pumpWidget(await rootWith(reporter, sink, devices));
      await tester.pump();

      expect(reporter.delegate, isNot(isA<CompositeCrashReporter>()));
      await reporter.recordError(StateError('lost Bedroom TV'), null);
      expect(sink.errors, isEmpty);
      expect(logging.errors.map((e) => e.reason), isNot(contains('startup')));

      devices.lists.add([savedTv(name: 'Bedroom TV')]);
      await tester.pump();

      expect(reporter.delegate, isA<CompositeCrashReporter>());
      await reporter.recordError(StateError('lost Bedroom TV'), null);
      expect(
        sink.errors.single.error.toString(),
        'StateError: Bad state: lost <tv>',
      );
      await tester.pumpAndSettle();
    });

    testWidgets('a_saved_list_that_never_answers_starts_without_a_seed', (
      tester,
    ) async {
      final reporter = DelegatingCrashReporter(RecordingCrashReporter());
      final sink = RecordingCrashlyticsSink();
      Widget? app;
      unawaited(
        rootWith(
          reporter,
          sink,
          _HangingDeviceRepository(),
        ).then((w) => app = w),
      );

      await tester.pump(const Duration(milliseconds: 400));
      expect(app, isNull, reason: 'still within the bound');
      await tester.pump(const Duration(milliseconds: 200));
      expect(app, isNotNull, reason: 'the read is bounded at 500 ms');
      // The saved names are still unknown, so nothing may reach Crashlytics.
      expect(reporter.delegate, isNot(isA<CompositeCrashReporter>()));

      await tester.pumpWidget(app!);
      await tester.pumpAndSettle();
    });

    Future<Widget> startWithALateRead(
      WidgetTester tester,
      DelegatingCrashReporter reporter,
      RecordingCrashlyticsSink sink,
      _LateDeviceRepository devices,
    ) async {
      Widget? app;
      unawaited(rootWith(reporter, sink, devices).then((w) => app = w));
      await tester.pump(const Duration(milliseconds: 600));
      expect(app, isNotNull, reason: 'the read is bounded at 500 ms');
      return app!;
    }

    testWidgets('a_timed_out_seed_sends_nothing_until_the_saved_list_arrives', (
      tester,
    ) async {
      final logging = RecordingCrashReporter();
      final reporter = DelegatingCrashReporter(logging);
      final sink = RecordingCrashlyticsSink();
      final devices = _LateDeviceRepository();
      final app = await startWithALateRead(tester, reporter, sink, devices);
      await tester.pumpWidget(app);
      await tester.pump();

      // Before the saved names are known: logged, never sent.
      await reporter.recordError(StateError('lost Bedroom TV'), null);
      expect(sink.errors, isEmpty);
      expect(logging.errors, hasLength(1));

      devices.lists.add([savedTv(name: 'Bedroom TV')]);
      await tester.pump();

      expect(reporter.delegate, isA<CompositeCrashReporter>());
      await reporter.recordError(StateError('lost Bedroom TV'), null);
      expect(
        sink.errors.single.error.toString(),
        'StateError: Bad state: lost <tv>',
      );
      await tester.pumpAndSettle();
    });

    testWidgets('a_late_seed_read_installs_the_scrubbing_reporter', (
      tester,
    ) async {
      final reporter = DelegatingCrashReporter(RecordingCrashReporter());
      final sink = RecordingCrashlyticsSink();
      final devices = _LateDeviceRepository();
      final app = await startWithALateRead(tester, reporter, sink, devices);
      await tester.pumpWidget(app);
      await tester.pump();
      expect(reporter.delegate, isNot(isA<CompositeCrashReporter>()));

      // The read answers late; the saved-list stream never emits.
      devices.read.complete([savedTv(name: 'Bedroom TV', nickname: 'Big')]);
      await tester.pump();

      expect(reporter.delegate, isA<CompositeCrashReporter>());
      await reporter.recordError(StateError('lost Bedroom TV (Big)'), null);
      expect(
        sink.errors.single.error.toString(),
        'StateError: Bad state: lost <tv> (<tv>)',
      );
      await tester.pumpAndSettle();
    });

    testWidgets('a_start_given_up_on_never_installs_its_late_reporter', (
      tester,
    ) async {
      final reporter = DelegatingCrashReporter(RecordingCrashReporter());
      final sink = RecordingCrashlyticsSink();
      final devices = _LateDeviceRepository();
      final app = await startWithALateRead(tester, reporter, sink, devices);
      await tester.pumpWidget(app);
      await tester.pump();

      // Try again: the first start's widget tree and container go away.
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      devices.read.complete([savedTv(name: 'Bedroom TV')]);
      await tester.pump();

      expect(reporter.delegate, isNot(isA<CompositeCrashReporter>()));
    });

    testWidgets('a_plain_reporter_is_left_alone_even_when_firebase_is_ready', (
      tester,
    ) async {
      final plain = RecordingCrashReporter();
      final sink = RecordingCrashlyticsSink();

      await tester.pumpWidget(await root(plain, sink, FirebaseStatus.ready));
      await tester.pumpAndSettle();

      expect(sink.untouched, isTrue);
    });

    testWidgets('a_reporter_that_cannot_be_built_does_not_stop_startup', (
      tester,
    ) async {
      final logging = RecordingCrashReporter();
      final reporter = DelegatingCrashReporter(logging);

      final app = await buildRootWidget(
        flavor: Flavor.dev,
        crashReporter: reporter,
        initFirebase: (_) async => FirebaseStatus.ready,
        openDatabase: () => AppDatabase(NativeDatabase.memory()),
        overrides: [
          ...fakeAdsOverrides(),
          crashlyticsSinkProvider.overrideWith(
            (ref) => throw StateError('no crashlytics'),
          ),
          deviceRepositoryProvider.overrideWithValue(
            InMemoryDeviceRepository(),
          ),
        ],
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      expect(find.text('Find your TV'), findsOneWidget);
      expect(reporter.delegate, same(logging));
      expect(logging.errors.single.reason, 'crash reporter setup');
    });
  });

  group('crash reporters', () {
    test('the_delegating_reporter_forwards_and_can_switch', () async {
      final first = RecordingCrashReporter();
      final second = RecordingCrashReporter();
      final reporter = DelegatingCrashReporter(first);

      await reporter.recordError('a', null, reason: 'one');
      await reporter.recordFlutterError(
        const FlutterErrorDetails(exception: 'f'),
        fatal: true,
      );
      reporter.delegate = second;
      await reporter.recordError('b', null, fatal: true);

      expect(first.errors.single.reason, 'one');
      expect(first.flutterErrors.single.fatal, isTrue);
      expect(second.errors.single.fatal, isTrue);
      expect(first.errors, hasLength(1));
    });

    test('the_composite_reporter_keeps_going_when_one_throws', () async {
      final good = RecordingCrashReporter();
      final reporter = CompositeCrashReporter([
        RecordingCrashReporter(throwOnRecord: true),
        good,
      ]);

      await reporter.recordError('x', null, reason: 'r');
      await reporter.recordFlutterError(
        const FlutterErrorDetails(exception: 'y'),
      );

      expect(good.errors.single.reason, 'r');
      expect(good.flutterErrors, hasLength(1));
    });
  });
}

/// A [FakeConfigSource] that notes its calls in a list shared with the test.
class _OrderSource extends FakeConfigSource {
  _OrderSource(this._order) : super(const {});

  final List<String> _order;

  @override
  Future<void> activateCached() {
    _order.add('activateCached');
    return super.activateCached();
  }

  @override
  Future<void> fetchForNextLaunch() {
    _order.add('fetchForNextLaunch');
    return super.fetchForNextLaunch();
  }
}

/// A store whose launch count write never finishes (a stuck platform
/// channel).
class _StuckLaunchCountStore extends SettingsStore {
  _StuckLaunchCountStore(super.prefs);

  @override
  Future<void> setLaunchCount(int value) => Completer<void>().future;
}

/// A store whose launch count can't be written.
class _NoLaunchCountStore extends SettingsStore {
  _NoLaunchCountStore(super.prefs);

  @override
  Future<void> setLaunchCount(int value) =>
      Future.error(StateError('disk full'));
}
