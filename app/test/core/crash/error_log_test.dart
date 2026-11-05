import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/core/analytics/app_analytics.dart';
import 'package:tv_remote/core/crash/crash_reporter.dart';
import 'package:tv_remote/core/crash/crash_scrubber.dart';
import 'package:tv_remote/core/crash/error_log.dart';
import 'package:tv_remote/core/crash/scrubbing_crash_reporter.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/discovery/application/discovery_controller.dart';
import 'package:tv_remote/features/discovery/data/discovery_providers.dart';

import '../../helpers/fake_tv_discovery.dart';
import '../../helpers/recording_analytics_sink.dart';

const _tvName = 'Bedroom TV';
const _ip = '192.168.0.42';
const _mac = 'AA:BB:CC:DD:EE:F0';

/// An error whose text carries a saved TV's name, an address and a MAC.
Exception _leaky() => Exception('Could not reach $_tvName at $_ip (mac $_mac)');

CrashScrubber _scrubber() => CrashScrubber(knownTerms: () => const [_tvName]);

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('error_log_');
    addTearDown(() => dir.deleteSync(recursive: true));
    file = File('${dir.path}/$errorLogFileName');
  });

  /// A log whose names are known and whose file is [file].
  ErrorLog boundLog({File? to, Future<void>? namesKnown}) {
    final log = ErrorLog()
      ..bind(
        namesKnown: namesKnown ?? Future<void>.value(),
        scrubber: _scrubber,
        file: () async => to ?? file,
      );
    // Runs before the directory goes: tear-downs run last-added first.
    addTearDown(() => log.idle);
    return log;
  }

  List<Map<String, Object?>> stored() {
    final decoded = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    return (decoded['entries']! as List<Object?>).cast();
  }

  test('the_log_never_stores_a_tv_name_or_address', () async {
    final log = boundLog();
    await log.idle;

    await log.recordError(
      _leaky(),
      StackTrace.fromString('#0 $_tvName ($_ip)'),
      reason: 'lost $_tvName',
    );
    await log.recordFlutterError(
      FlutterErrorDetails(
        exception: FlutterError('Failed for $_tvName at $_ip'),
        context: ErrorDescription('while talking to $_tvName'),
        informationCollector: () => [
          ErrorDescription('typed text must never be read'),
        ],
      ),
    );
    await log.idle;

    final text = file.readAsStringSync();
    expect(text, isNotEmpty);
    for (final leak in const [_tvName, _ip, _mac]) {
      expect(text, isNot(contains(leak)), reason: leak);
    }
    expect(text, isNot(contains('typed text')));
    expect(text, contains('<tv>'));
    expect(text, contains('<ip>'));
    expect(text, contains('<mac>'));
    for (final entry in log.entries) {
      final shown = '${entry.message} ${entry.reason} ${entry.stack}';
      for (final leak in const [_tvName, _ip, _mac]) {
        expect(shown, isNot(contains(leak)), reason: leak);
      }
    }
  });

  // Ruling P9-C17: the value being saved is unknown to the scrubber, because
  // the save failed.
  test('a_failed_save_never_stores_the_value_it_was_saving', () async {
    final log = boundLog();
    await log.idle;
    const unsaved = 'Sarah bedroom';

    await log.recordError(
      SqliteException(
        extendedResultCode: 13,
        message: 'database or disk is full',
        causingStatement: 'UPDATE devices SET nickname = ? WHERE id = ?',
        parametersToStatement: [unsaved, 'id'],
      ),
      null,
      reason: 'device save',
    );
    await log.idle;

    expect(file.readAsStringSync(), isNot(contains(unsaved)));
    expect(log.entries.single.message, isNot(contains(unsaved)));
    expect(log.entries.single.message, contains('database or disk is full'));
  });

  test(
    'an_entry_holds_the_time_fatal_reason_message_and_eight_frames',
    () async {
      final log = boundLog();
      await log.idle;
      final stack = StackTrace.fromString(
        [for (var i = 0; i < 12; i++) '#$i frame$i'].join('\n'),
      );

      await withClock(
        Clock.fixed(DateTime.utc(2026, 11, 5, 9, 30)),
        () => log.recordError(
          StateError('boom'),
          stack,
          fatal: true,
          reason: 'startup',
        ),
      );
      await log.idle;

      final entry = log.entries.single;
      expect(entry.time, DateTime.utc(2026, 11, 5, 9, 30));
      expect(entry.time.isUtc, isTrue);
      expect(entry.fatal, isTrue);
      expect(entry.reason, 'startup');
      expect(entry.message, 'StateError: Bad state: boom');
      expect(entry.stack, hasLength(errorLogStackFrames));
      expect(entry.stack.first, '#0 frame0');
      expect(entry.stack.last, '#7 frame7');
      expect(stored().single['reason'], 'startup');
    },
  );

  test('a_long_message_is_clipped_after_scrubbing', () async {
    final log = boundLog();
    await log.idle;

    await log.recordError(Exception('x' * 5000), null);

    expect(
      log.entries.single.message.length,
      ScrubbingCrashReporter.maxLength,
    );
  });

  test('entry_51_drops_the_oldest', () async {
    final log = boundLog();
    await log.idle;

    for (var i = 1; i <= errorLogCapacity + 1; i++) {
      await log.recordError(Exception('error $i'), null);
    }
    await log.idle;

    expect(log.entries, hasLength(errorLogCapacity));
    expect(log.entries.first.message, contains('error 51'));
    expect(log.entries.last.message, contains('error 2'));
    expect(log.entries.last.message, isNot(contains('error 1 ')));
    expect(stored(), hasLength(errorLogCapacity));
    expect(stored().first['message'], contains('error 2'));
  });

  test('entries_are_newest_first_and_survive_a_restart', () async {
    final first = boundLog();
    await first.idle;
    await first.recordError(Exception('older'), null);
    await first.idle;

    final second = boundLog();
    await second.idle;
    await second.recordError(Exception('newer'), null);
    await second.idle;

    expect(second.entries.first.message, contains('newer'));
    expect(second.entries.last.message, contains('older'));
    expect(stored(), hasLength(2));
  });

  group('the hold (decision #50)', () {
    test('nothing_is_shown_or_written_until_the_names_are_known', () async {
      final known = Completer<void>();
      final log = boundLog(namesKnown: known.future);
      await log.recordError(_leaky(), null, reason: 'early');
      await pumpEventQueue();
      await log.idle;

      expect(log.entries, isEmpty, reason: 'not shown');
      expect(file.existsSync(), isFalse, reason: 'not written');

      known.complete();
      await pumpEventQueue();
      await log.idle;

      expect(log.entries.single.reason, 'early');
      final text = file.readAsStringSync();
      for (final leak in const [_tvName, _ip, _mac]) {
        expect(text, isNot(contains(leak)), reason: leak);
      }
      expect(text, contains('<tv>'));
    });

    test('names_that_never_arrive_keep_it_out_of_the_file', () async {
      final log = boundLog(namesKnown: Completer<void>().future);
      await log.recordError(_leaky(), null);
      await pumpEventQueue();
      await log.idle;

      expect(log.entries, isEmpty);
      expect(file.existsSync(), isFalse);
    });

    test('an_unbound_log_shows_and_writes_nothing', () async {
      final log = ErrorLog();
      await log.recordError(_leaky(), null);

      expect(log.entries, isEmpty);
    });
  });

  group('storage failures', () {
    test('a_corrupt_file_starts_empty', () async {
      file.writeAsStringSync('{not json');
      final log = boundLog();
      await log.idle;

      expect(log.entries, isEmpty);
      await log.recordError(Exception('after'), null);
      await log.idle;
      expect(stored(), hasLength(1));
    });

    test('a_file_of_the_wrong_shape_starts_empty', () async {
      file.writeAsStringSync('{"entries": [{"time": 3}, 7]}');
      final log = boundLog();
      await log.idle;

      expect(log.entries, isEmpty);
    });

    test('a_failing_write_does_not_throw_and_keeps_the_entry', () async {
      final log = boundLog(to: File('${dir.path}/missing/dir/log.json'));
      await log.idle;

      await log.recordError(Exception('kept'), null);
      await log.idle;

      expect(log.entries.single.message, contains('kept'));
    });

    test('a_file_lookup_that_fails_leaves_it_working_in_memory', () async {
      final log = ErrorLog()
        ..bind(
          namesKnown: Future<void>.value(),
          scrubber: _scrubber,
          file: () async => throw StateError('no directory'),
        );
      await log.idle;

      await log.recordError(Exception('kept'), null);

      expect(log.entries.single.message, contains('kept'));
    });

    test('no_file_at_all_is_memory_only', () async {
      final log = ErrorLog()
        ..bind(
          namesKnown: Future<void>.value(),
          scrubber: _scrubber,
          file: () async => null,
        );
      await log.idle;

      await log.recordError(Exception('kept'), null);
      await log.idle;

      expect(log.entries.single.message, contains('kept'));
    });

    test('writes_are_atomic_and_leave_no_tmp_file', () async {
      final log = boundLog();
      await log.idle;

      await Future.wait([
        for (var i = 0; i < 10; i++) log.recordError(Exception('e$i'), null),
      ]);
      await log.idle;

      expect(stored(), hasLength(10));
      expect(
        dir.listSync().map((e) => e.uri.pathSegments.last),
        [errorLogFileName],
      );
    });
  });

  test('clear_empties_the_list_and_the_file', () async {
    final log = boundLog();
    await log.idle;
    await log.recordError(Exception('gone'), null);
    await log.idle;

    await log.clear();
    await log.idle;

    expect(log.entries, isEmpty);
    expect(stored(), isEmpty);
  });

  test('it_tells_listeners_about_new_entries', () async {
    final log = boundLog();
    await log.idle;
    var notified = 0;
    log.addListener(() => notified++);

    await log.recordError(Exception('x'), null);

    expect(notified, 1);
  });

  // It sits in the reporter chain and is told everything; sharing, Firebase
  // and the build type are ScrubbingCrashReporter's business, not its own.
  test('it_has_no_sharing_firebase_or_build_type_gate', () async {
    final log = boundLog();
    await log.idle;
    final reporter = CompositeCrashReporter([
      const LoggingCrashReporter(),
      log,
    ]);

    await reporter.recordError(Exception('recorded'), null);

    expect(kDebugMode, isTrue, reason: 'flutter test is a debug build');
    expect(log.entries.single.message, contains('recorded'));
  });

  test('a_failed_search_is_recorded', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final settings = await SettingsStore.open();
    final discoveries = FakeTvDiscoveries();
    final log = boundLog();
    await log.idle;
    final c = ProviderContainer.test(
      overrides: [
        tvDiscoveryFactoryProvider.overrideWithValue(discoveries.create),
        settingsStoreProvider.overrideWithValue(settings),
        analyticsSinkProvider.overrideWithValue(RecordingAnalyticsSink()),
        crashReporterProvider.overrideWithValue(log),
      ],
    )..listen(discoveryControllerProvider, (_, _) {});

    discoveries.created.single.fail(
      TvConnectionException('nsd refused $_tvName'),
    );
    await pumpEventQueue();

    final entry = log.entries.single;
    expect(entry.reason, 'discovery');
    expect(entry.fatal, isFalse);
    expect(entry.message, contains('nsd refused'));
    expect(entry.message, isNot(contains(_tvName)));
    c.dispose();
  });
}

/// An error with a message, as a plugin would raise.
class TvConnectionException implements Exception {
  /// Creates the error.
  TvConnectionException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => 'TvConnectionException: $message';
}
