import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/app/flavor.dart';
import 'package:tv_remote/bootstrap.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/settings_store.dart';

import 'helpers/recording_crash_reporter.dart';

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
      void Function() fixFailure,
    ) async {
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

      fixFailure();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('The app could not start'), findsNothing);
      expect(find.text('Get started'), findsOneWidget);
      expect(reporter.errors, hasLength(1));
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
      });
    });
  });
}
