import 'package:flutter/foundation.dart';
import 'package:tv_remote/core/crash/crash_reporter.dart';

/// A reported non-Flutter error.
typedef RecordedError = ({
  Object error,
  StackTrace? stack,
  bool fatal,
  String? reason,
});

/// A reported [FlutterErrorDetails].
typedef RecordedFlutterError = ({FlutterErrorDetails details, bool fatal});

/// A [CrashReporter] that remembers what it was given.
///
/// With [throwOnRecord] every call throws, to test that callers cope with a
/// failing reporter.
class RecordingCrashReporter implements CrashReporter {
  /// Creates a recorder.
  RecordingCrashReporter({this.throwOnRecord = false});

  /// Whether calls throw instead of recording.
  final bool throwOnRecord;

  /// Errors reported through `recordError`.
  final List<RecordedError> errors = [];

  /// Errors reported through `recordFlutterError`.
  final List<RecordedFlutterError> flutterErrors = [];

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
  }) async {
    if (throwOnRecord) throw StateError('reporter is broken');
    errors.add((error: error, stack: stack, fatal: fatal, reason: reason));
  }

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) async {
    if (throwOnRecord) throw StateError('reporter is broken');
    flutterErrors.add((details: details, fatal: fatal));
  }
}
