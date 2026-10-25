import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'crash_reporter.g.dart';

/// Where errors are reported. Phase 6 adds a Crashlytics implementation.
abstract interface class CrashReporter {
  /// Reports [error]. [fatal] marks an error that ended the current work;
  /// [reason] says where it came from.
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
  });

  /// Reports a framework error.
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  });
}

/// A [CrashReporter] that only writes to the developer log. It sends nothing
/// over the network.
class LoggingCrashReporter implements CrashReporter {
  /// Creates a logging reporter.
  const LoggingCrashReporter();

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
  }) async {
    final label = fatal ? 'Fatal error' : 'Error';
    final message = reason == null ? label : '$label ($reason)';
    developer.log(
      message,
      name: 'crash',
      level: fatal ? 1000 : 900,
      error: error,
      stackTrace: stack,
    );
    _echo(message, error, stack);
  }

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) async {
    final message =
        '${fatal ? 'Fatal Flutter error' : 'Flutter error'}: '
        '${details.exceptionAsString()}';
    developer.log(
      message,
      name: 'crash',
      level: fatal ? 1000 : 900,
      error: details.exception,
      stackTrace: details.stack,
    );
    _echo(message, details.exception, details.stack);
  }

  // `developer.log` does not show in `flutter run` or logcat output, so debug
  // builds print the error as well.
  void _echo(String message, Object error, StackTrace? stack) {
    if (!kDebugMode) return;
    debugPrint('$message\n$error${stack == null ? '' : '\n$stack'}');
  }
}

/// The app's crash reporter.
@Riverpod(keepAlive: true)
CrashReporter crashReporter(Ref ref) => const LoggingCrashReporter();
