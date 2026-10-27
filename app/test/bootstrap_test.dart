import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/app/flavor.dart';
import 'package:tv_remote/bootstrap.dart';
import 'package:tv_remote/core/config/service_config.dart';
import 'package:tv_remote/core/crash/crash_collection.dart';
import 'package:tv_remote/core/crash/crash_reporter.dart';
import 'package:tv_remote/core/firebase/firebase_bootstrap.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';

import 'helpers/in_memory_device_repository.dart';
import 'helpers/recording_crash_reporter.dart';
import 'helpers/recording_crashlytics_sink.dart';

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
    setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
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
      expect(find.text('Get started'), findsNothing);
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
      expect(find.text('Get started'), findsOneWidget);
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
      expect(find.text('Get started'), findsOneWidget);
    });
  });
  group('Firebase startup', () {
    setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
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

      expect(find.text('Get started'), findsOneWidget);
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
      expect(find.text('Get started'), findsOneWidget);
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
      expect(find.text('Get started'), findsOneWidget);
      expect(builds, 1);
    });

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

      expect(find.text('Get started'), findsOneWidget);
      expect(builds, 1);
      expect(opens, 1);
    });
  });

  group('Crashlytics reporter', () {
    setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
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

      expect(find.text('Get started'), findsOneWidget);
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
