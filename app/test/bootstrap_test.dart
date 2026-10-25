import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/bootstrap.dart';

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
}
