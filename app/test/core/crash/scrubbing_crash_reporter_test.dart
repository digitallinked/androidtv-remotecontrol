import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/crash/crash_scrubber.dart';
import 'package:tv_remote/core/crash/scrubbing_crash_reporter.dart';

import '../../helpers/recording_crashlytics_sink.dart';

void main() {
  late RecordingCrashlyticsSink sink;
  var enabled = true;

  ScrubbingCrashReporter reporter({bool isDebugBuild = false}) =>
      ScrubbingCrashReporter(
        sink: sink,
        scrubber: CrashScrubber(knownTerms: () => const ['Living Room TV 3']),
        enabled: () => enabled,
        isDebugBuild: isDebugBuild,
      );

  setUp(() {
    sink = RecordingCrashlyticsSink();
    enabled = true;
  });

  test('sends_only_scrubbed_text', () async {
    final stack = StackTrace.fromString('#0 main (package:a/a.dart:1:1)');

    await reporter().recordError(
      StateError('TV Living Room TV 3 at 192.168.0.20'),
      stack,
      fatal: true,
      reason: 'connect to Living Room TV 3',
    );

    final sent = sink.errors.single;
    expect(sent.error, isA<ScrubbedError>());
    expect(sent.error.toString(), startsWith('StateError: '));
    expect(sent.error.toString(), isNot(contains('Living')));
    expect(sent.error.toString(), isNot(contains('192.168')));
    expect(sent.reason, 'connect to <tv>');
    expect(sent.fatal, isTrue);
    expect(sent.stack, same(stack));
  });

  test('a_missing_reason_stays_missing', () async {
    await reporter().recordError('x', null);
    expect(sink.errors.single.reason, isNull);
    expect(sink.errors.single.fatal, isFalse);
  });

  test('flutter_errors_send_the_scrubbed_exception_and_context', () async {
    await reporter().recordFlutterError(
      FlutterErrorDetails(
        exception: StateError('bad 10.1.2.3'),
        stack: StackTrace.current,
        context: ErrorDescription('while sending to Living Room TV 3'),
      ),
      fatal: true,
    );

    final sent = sink.errors.single;
    expect(sent.error.toString(), startsWith('StateError: '));
    expect(sent.error.toString(), isNot(contains('10.1.2.3')));
    expect(sent.reason, 'while sending to <tv>');
    expect(sent.fatal, isTrue);
  });

  test('flutter_errors_drop_their_information', () async {
    var collected = false;
    await reporter().recordFlutterError(
      FlutterErrorDetails(
        exception: 'x',
        informationCollector: () sync* {
          collected = true;
          yield DiagnosticsNode.message('typed: hunter2');
        },
      ),
    );

    expect(collected, isFalse);
    final sent = sink.errors.single;
    expect('${sent.error} ${sent.reason}', isNot(contains('hunter2')));
    expect(sent.reason, isNull);
  });

  test('nothing_is_sent_when_crash_reports_are_off', () async {
    enabled = false;
    final r = reporter();

    await r.recordError('x', null);
    await r.recordFlutterError(const FlutterErrorDetails(exception: 'y'));

    expect(sink.untouched, isTrue);

    enabled = true;
    await r.recordError('x', null);
    expect(sink.errors, hasLength(1));
  });

  test('nothing_is_sent_from_debug_builds', () async {
    final r = reporter(isDebugBuild: true);

    await r.recordError('x', null, fatal: true);
    await r.recordFlutterError(const FlutterErrorDetails(exception: 'y'));

    expect(sink.untouched, isTrue);
  });

  test('sink_failures_never_throw', () async {
    sink = RecordingCrashlyticsSink(throwOnCall: true);
    final r = reporter();

    await r.recordError('x', null);
    await r.recordFlutterError(const FlutterErrorDetails(exception: 'y'));
  });

  test('a_failing_enabled_check_sends_nothing_and_never_throws', () async {
    final r = ScrubbingCrashReporter(
      sink: sink,
      scrubber: CrashScrubber(),
      enabled: () => throw StateError('disposed'),
      isDebugBuild: false,
    );

    await r.recordError('x', null);
    await r.recordFlutterError(const FlutterErrorDetails(exception: 'y'));

    expect(sink.untouched, isTrue);
  });

  test('a_scrubber_whose_terms_fail_still_sends_scrubbed_text', () async {
    final r = ScrubbingCrashReporter(
      sink: sink,
      scrubber: CrashScrubber(knownTerms: () => throw StateError('x')),
      enabled: () => true,
      isDebugBuild: false,
    );

    await r.recordError('at 10.0.0.1', null);

    expect(sink.errors.single.error.toString(), 'String: at <ip>');
  });

  test('scrubbed_error_prints_its_message', () {
    expect(const ScrubbedError('A: b').toString(), 'A: b');
  });
}
