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

/// What a report says, before anything is scrubbed. The one place that
/// decides which parts of an error may be used at all, for Crashlytics and
/// the on-phone error log alike.
final class ReportFacts {
  /// Facts of a caught error.
  ReportFacts.ofError(Object error, this.stack, {this.reason})
    : type = error.runtimeType,
      message = error.toString;

  /// Facts of a framework error.
  ///
  /// A framework error's full text is a diagnostics dump that can quote
  /// widgets and values, so only its summary line is used. The reason is the
  /// context's own description; `informationCollector`, which can hold widget
  /// values such as typed text, is never read.
  ReportFacts.ofFlutterError(FlutterErrorDetails details)
    : type = details.exception.runtimeType,
      message = details.exception is FlutterError
          ? details.summary.toDescription
          : details.exceptionAsString,
      stack = details.stack,
      reason = details.context?.toDescription();

  /// The error's type.
  final Type type;

  /// Reads the raw message. Unscrubbed: it never goes anywhere as it is.
  final String Function() message;

  /// The stack trace.
  final StackTrace? stack;

  /// The raw reason. Unscrubbed, like [message].
  final String? reason;

  /// The scrubbed `'<type>: <message>'`, clipped after scrubbing.
  String scrubbedMessage(CrashScrubber scrubber) =>
      scrubbedMessageOf(type, message(), scrubber);

  /// The scrubbed, clipped reason, or `null` when there is none.
  String? scrubbedReason(CrashScrubber scrubber) =>
      scrubbedReasonOf(reason, scrubber);

  /// [scrubbedMessage] of a message already read.
  static String scrubbedMessageOf(
    Type type,
    String message,
    CrashScrubber scrubber,
  ) => clip('$type: ${scrubber.scrub(message)}');

  /// [scrubbedReason] of a reason already read.
  static String? scrubbedReasonOf(String? reason, CrashScrubber scrubber) =>
      reason == null ? null : clip(scrubber.scrub(reason));

  /// [text] cut to [ScrubbingCrashReporter.maxLength]. A cut is made after
  /// scrubbing, so it can never split a pattern the scrubber would have
  /// recognised.
  static String clip(String text) =>
      text.length <= ScrubbingCrashReporter.maxLength
      ? text
      : text.substring(0, ScrubbingCrashReporter.maxLength);
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
  }) => _send(ReportFacts.ofError(error, stack, reason: reason), fatal: fatal);

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) => _send(ReportFacts.ofFlutterError(details), fatal: fatal);

  /// The longest text sent. A cut is made after scrubbing, so it can never
  /// split a pattern the scrubber would have recognised.
  static const maxLength = 1024;

  Future<void> _send(ReportFacts facts, {required bool fatal}) async {
    try {
      if (_isDebugBuild || !_enabled()) return;
      await _sink.recordError(
        ScrubbedError(facts.scrubbedMessage(_scrubber)),
        facts.stack,
        reason: facts.scrubbedReason(_scrubber),
        fatal: fatal,
      );
    } on Object {
      // Reporting must never become a second crash.
    }
  }
}
