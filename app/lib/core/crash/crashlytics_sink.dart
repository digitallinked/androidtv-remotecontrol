import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Where scrubbed crash reports are handed to Crashlytics.
///
/// This file and its implementation are the only code that imports
/// `firebase_crashlytics`; everything else talks to this interface, so tests
/// use a recording fake.
abstract interface class CrashlyticsSink {
  /// Records [error] with [stack]. [reason] says where it came from; [fatal]
  /// marks an error that ended the current work.
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal,
  });

  /// Turns native collection and sending on or off. While it is off,
  /// Crashlytics keeps reports on the device.
  // The brief fixes this positional signature.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setCollectionEnabled(bool enabled);

  /// Deletes the reports waiting on the device.
  Future<void> deleteUnsentReports();
}

/// The [CrashlyticsSink] backed by `FirebaseCrashlytics.instance`.
///
/// Every call catches everything, `MissingPluginException` included: a
/// reporting failure must never become a second crash.
class FirebaseCrashlyticsSink implements CrashlyticsSink {
  /// Creates the sink. It touches Firebase only when a method is called.
  const FirebaseCrashlyticsSink();

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) async {
    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: reason,
        fatal: fatal,
        // The text is already scrubbed; nothing goes to the console.
        printDetails: false,
      );
    } on Object {
      // Nothing more can be done about a failing Crashlytics.
    }
  }

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        enabled,
      );
    } on Object {
      // Collection stays off natively until it can be turned on.
    }
  }

  @override
  Future<void> deleteUnsentReports() async {
    try {
      await FirebaseCrashlytics.instance.deleteUnsentReports();
    } on Object {
      // Nothing to delete if Crashlytics is not running.
    }
  }
}
