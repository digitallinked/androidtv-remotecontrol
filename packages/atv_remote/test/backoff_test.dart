import 'package:atv_remote/src/backoff.dart';
import 'package:test/test.dart';

void main() {
  test('backoff_sequence_1_2_4_8_16_30_then_null', () {
    final backoff = Backoff();
    final delays = [for (var i = 0; i < 6; i++) backoff.next()];
    expect(delays, [
      const Duration(seconds: 1),
      const Duration(seconds: 2),
      const Duration(seconds: 4),
      const Duration(seconds: 8),
      const Duration(seconds: 16),
      const Duration(seconds: 30),
    ]);
    expect(backoff.next(), isNull);
    expect(backoff.next(), isNull, reason: 'stays exhausted');
  });

  test('reset_restarts_the_sequence', () {
    final backoff = Backoff();
    while (backoff.next() != null) {}
    backoff.reset();
    expect(backoff.next(), const Duration(seconds: 1));
    expect(backoff.next(), const Duration(seconds: 2));
  });

  test('custom_initial_and_max_double_and_cap', () {
    final backoff = Backoff(
      initial: const Duration(milliseconds: 10),
      max: const Duration(milliseconds: 40),
    );
    final delays = [for (var i = 0; i < 6; i++) backoff.next()];
    expect(delays, [
      const Duration(milliseconds: 10),
      const Duration(milliseconds: 20),
      const Duration(milliseconds: 40),
      const Duration(milliseconds: 40),
      const Duration(milliseconds: 40),
      const Duration(milliseconds: 40),
    ]);
    expect(backoff.next(), isNull);
  });

  test('max_attempts_limits_the_number_of_delays', () {
    final backoff = Backoff(maxAttempts: 2);
    expect(backoff.next(), const Duration(seconds: 1));
    expect(backoff.next(), const Duration(seconds: 2));
    expect(backoff.next(), isNull);
  });
}
