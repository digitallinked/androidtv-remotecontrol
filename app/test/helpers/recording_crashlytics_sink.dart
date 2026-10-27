import 'package:tv_remote/core/crash/crashlytics_sink.dart';

/// A reported error as the sink received it.
typedef SunkError = ({
  Object error,
  StackTrace? stack,
  String? reason,
  bool fatal,
});

/// A [CrashlyticsSink] that remembers what it was given.
///
/// With [throwOnCall] every call throws, to test that callers cope with a
/// failing sink.
class RecordingCrashlyticsSink implements CrashlyticsSink {
  /// Creates a recording sink.
  RecordingCrashlyticsSink({this.throwOnCall = false});

  /// Whether every call throws instead of recording.
  final bool throwOnCall;

  /// Errors passed to `recordError`.
  final List<SunkError> errors = [];

  /// Every value passed to `setCollectionEnabled`, in order.
  final List<bool> collectionHistory = [];

  /// How often `deleteUnsentReports` was called.
  int deletes = 0;

  /// Every `setCollectionEnabled` and `deleteUnsentReports` call, in order:
  /// `enable:true`, `enable:false`, `delete`.
  final List<String> calls = [];

  /// Whether the sink was never called.
  bool get untouched =>
      errors.isEmpty && collectionHistory.isEmpty && deletes == 0;

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) async {
    if (throwOnCall) throw StateError('sink is broken');
    errors.add((error: error, stack: stack, reason: reason, fatal: fatal));
  }

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    if (throwOnCall) throw StateError('sink is broken');
    collectionHistory.add(enabled);
    calls.add('enable:$enabled');
  }

  @override
  Future<void> deleteUnsentReports() async {
    if (throwOnCall) throw StateError('sink is broken');
    deletes++;
    calls.add('delete');
  }
}
