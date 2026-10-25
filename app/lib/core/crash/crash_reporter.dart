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
    developer.log(
      '${fatal ? 'Fatal error' : 'Error'}${reason == null ? '' : ' ($reason)'}',
      name: 'crash',
      level: fatal ? 1000 : 900,
      error: error,
      stackTrace: stack,
    );
  }

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) async {
    developer.log(
      '${fatal ? 'Fatal Flutter error' : 'Flutter error'}: '
      '${details.exceptionAsString()}',
      name: 'crash',
      level: fatal ? 1000 : 900,
      error: details.exception,
      stackTrace: details.stack,
    );
  }
}

/// The app's crash reporter.
@Riverpod(keepAlive: true)
CrashReporter crashReporter(Ref ref) => const LoggingCrashReporter();
