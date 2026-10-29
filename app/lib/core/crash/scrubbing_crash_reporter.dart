import 'package:flutter/foundation.dart';
import 'package:tv_remote/core/crash/crash_reporter.dart';
import 'package:tv_remote/core/crash/crash_scrubber.dart';
import 'package:tv_remote/core/crash/crashlytics_sink.dart';

/// An error whose text has already been scrubbed; what Crashlytics receives
/// in place of the original error object.
final class ScrubbedError {
  /// Creates an error that prints as [message].
  const ScrubbedError(this.message);

  /// The scrubbed `'<runtimeType>: <message>'`.
  final String message;

  @override
  String toString() => message;
}

/// A [CrashReporter] that scrubs every report and hands it to a
/// [CrashlyticsSink] (Ruling P6-R5).
///
/// It sends the error's type and scrubbed message, the original stack trace
/// (Dart frames carry no data) and a scrubbed reason. For a framework error
/// it never reads `informationCollector`, which can hold widget values such
/// as typed text. It never sets a user ID or custom keys.
///
/// It sends nothing when `enabled` says no or in a debug build, and it never
/// throws.
class ScrubbingCrashReporter implements CrashReporter {
  /// Creates a reporter. `enabled` is asked for every report, so a change of
  /// the user's choice applies at once.
  ScrubbingCrashReporter({
    required this._sink,
    required this._scrubber,
    required this._enabled,
    this._isDebugBuild = kDebugMode,
  });

  final CrashlyticsSink _sink;
  final CrashScrubber _scrubber;
  final bool Function() _enabled;
  final bool _isDebugBuild;

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
  }) => _send(
    error.runtimeType,
    error.toString,
    stack,
    reason: reason,
    fatal: fatal,
  );

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) => _send(
    details.exception.runtimeType,
    // A framework error's full text is a diagnostics dump that can quote
    // widgets and values; only its summary line is sent.
    details.exception is FlutterError
        ? details.summary.toDescription
        : details.exceptionAsString,
    details.stack,
    // Only the context's own description; `informationCollector` is dropped.
    reason: details.context?.toDescription(),
    fatal: fatal,
  );

  /// The longest text sent. A cut is made after scrubbing, so it can never
  /// split a pattern the scrubber would have recognised.
  static const maxLength = 1024;

  static String _clip(String text) =>
      text.length <= maxLength ? text : text.substring(0, maxLength);

  Future<void> _send(
    Type type,
    String Function() message,
    StackTrace? stack, {
    required String? reason,
    required bool fatal,
  }) async {
    try {
      if (_isDebugBuild || !_enabled()) return;
      await _sink.recordError(
        ScrubbedError(_clip('$type: ${_scrubber.scrub(message())}')),
        stack,
        reason: reason == null ? null : _clip(_scrubber.scrub(reason)),
        fatal: fatal,
      );
    } on Object {
      // Reporting must never become a second crash.
    }
  }
}
