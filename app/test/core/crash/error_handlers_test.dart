import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/crash/error_handlers.dart';

import '../../helpers/recording_crash_reporter.dart';

void main() {
  setUp(() {
    final savedOnError = FlutterError.onError;
    final savedPresentError = FlutterError.presentError;
    final savedPlatformOnError = PlatformDispatcher.instance.onError;
    // Keep the test log free of the printed error report.
    FlutterError.presentError = (_) {};
    addTearDown(() {
      FlutterError.onError = savedOnError;
      FlutterError.presentError = savedPresentError;
      PlatformDispatcher.instance.onError = savedPlatformOnError;
    });
  });

  test('flutter_error_is_forwarded_as_fatal', () {
    final recorder = RecordingCrashReporter();
    installErrorHandlers(recorder);

    FlutterError.onError!(FlutterErrorDetails(exception: StateError('x')));

    expect(recorder.flutterErrors.single.fatal, isTrue);
    expect(recorder.flutterErrors.single.details.exception, isA<StateError>());
  });

  test('platform_error_is_forwarded_and_marked_handled', () {
    final recorder = RecordingCrashReporter();
    installErrorHandlers(recorder);

    final handled = PlatformDispatcher.instance.onError!(
      StateError('y'),
      StackTrace.empty,
    );

    expect(handled, isTrue);
    expect(recorder.errors.single.error, isA<StateError>());
    expect(recorder.errors.single.fatal, isTrue);
  });

  test('reporter_failure_is_swallowed', () async {
    installErrorHandlers(RecordingCrashReporter(throwOnRecord: true));

    FlutterError.onError!(FlutterErrorDetails(exception: StateError('x')));
    final handled = PlatformDispatcher.instance.onError!(
      StateError('y'),
      StackTrace.empty,
    );
    await Future<void>.delayed(Duration.zero);

    expect(handled, isTrue);
  });
}
