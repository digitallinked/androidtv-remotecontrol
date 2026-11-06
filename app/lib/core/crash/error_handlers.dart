import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Reports the failure a screen starts showing as [next] arrives, for a
/// provider listener (Ruling P9-C17). [shown] is the screen's own failure
/// condition, so a state that stays failed is one report and a retry that
/// fails again is a new one.
void reportShownFailure<T>(
  CrashReporter reporter,
  AsyncValue<T>? previous,
  AsyncValue<T> next, {
  required bool Function(AsyncValue<T> state) shown,
  required String reason,
}) {
  if (!shown(next) || (previous != null && shown(previous))) return;
  final error = next.error;
  if (error == null) return;
  unawaited(safeRecordError(reporter, error, next.stackTrace, reason: reason));
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
