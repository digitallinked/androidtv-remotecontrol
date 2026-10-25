import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tv_remote/core/crash/crash_reporter.dart';

/// Reports [error] to [reporter] and never throws, even when the reporter
/// throws or its future fails. Reporting must not become a second crash.
Future<void> safeRecordError(
  CrashReporter reporter,
  Object error,
  StackTrace? stack, {
  bool fatal = false,
  String? reason,
}) async {
  try {
    await reporter.recordError(error, stack, fatal: fatal, reason: reason);
  } on Object {
    // Nothing more can be done about a failing reporter.
  }
}

/// Sends framework and uncaught platform errors to [reporter].
///
/// Framework errors are still printed to the console first. Failures of the
/// reporter itself are swallowed.
void installErrorHandlers(CrashReporter reporter) {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(_safeRecordFlutterError(reporter, details));
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(safeRecordError(reporter, error, stack, fatal: true));
    return true;
  };
}

Future<void> _safeRecordFlutterError(
  CrashReporter reporter,
  FlutterErrorDetails details,
) async {
  try {
    await reporter.recordFlutterError(details, fatal: true);
  } on Object {
    // Nothing more can be done about a failing reporter.
  }
}
