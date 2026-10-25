import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/crash/crash_reporter.dart';

void main() {
  late List<String> printed;

  setUp(() {
    final saved = debugPrint;
    printed = [];
    debugPrint = (message, {wrapWidth}) {
      if (message != null) printed.add(message);
    };
    addTearDown(() => debugPrint = saved);
  });

  test('record_error_prints_error_and_stack_in_debug_builds', () async {
    final stack = StackTrace.fromString('#0 frame_marker');

    await const LoggingCrashReporter().recordError(
      StateError('boom'),
      stack,
      reason: 'startup',
    );

    final output = printed.join('\n');
    expect(output, contains('Error (startup)'));
    expect(output, contains('boom'));
    expect(output, contains('frame_marker'));
  });

  test('record_flutter_error_prints_error_and_stack_in_debug_builds', () async {
    await const LoggingCrashReporter().recordFlutterError(
      FlutterErrorDetails(
        exception: StateError('widget boom'),
        stack: StackTrace.fromString('#0 widget_frame'),
      ),
      fatal: true,
    );

    final output = printed.join('\n');
    expect(output, contains('Fatal Flutter error'));
    expect(output, contains('widget boom'));
    expect(output, contains('widget_frame'));
  });
}
