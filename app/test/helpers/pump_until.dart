import 'package:flutter_test/flutter_test.dart';

/// Pumps frames until [condition] holds, letting real asynchronous work (the
/// sockets of the fake TV) run between them.
///
/// Each round gives the real event loop 16 ms through `runAsync`, then pumps
/// one frame without moving the fake clock, so the app's own timers (the
/// idle timeout, the reconnect backoff) never fire by accident. The frame is
/// pumped with [Duration.zero] rather than no duration: that runs the
/// zero-length timers dart:io's TLS sockets schedule in the test's zone,
/// which a plain `pump()` never does. The wait is
/// bounded by [timeout] of real time; when it runs out, it fails the test
/// with a [TestFailure] that names [reason], what it was waiting for.
Future<void> pumpUntil(
  WidgetTester t,
  bool Function() condition, {
  required String reason,
  Duration timeout = const Duration(seconds: 20),
}) async {
  final watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed >= timeout) {
      throw TestFailure('Timed out after $timeout waiting for $reason');
    }
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 16)),
    );
    await t.pump(Duration.zero);
  }
}
