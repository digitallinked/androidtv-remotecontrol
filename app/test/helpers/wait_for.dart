import 'package:flutter_test/flutter_test.dart';

/// Waits, in real time, until [condition] holds, checking every 10 ms.
///
/// For plain `test()`s that talk to the fake TV over real sockets (widget
/// tests use `pumpUntil` instead): they wait on a condition, never on a fixed
/// delay. Running out of [timeout] is the failure, and it names [reason],
/// what the test was waiting for.
Future<void> waitFor(
  bool Function() condition, {
  required String reason,
  Duration timeout = const Duration(seconds: 20),
}) async {
  final watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed >= timeout) {
      throw TestFailure('Timed out after $timeout waiting for $reason');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
