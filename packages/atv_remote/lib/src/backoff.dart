/// Exponential delays between reconnect attempts.
///
/// [next] yields [initial], twice that, and so on, never more than [max]
/// (with the defaults: 1 s, 2 s, 4 s, 8 s, 16 s, 30 s), and then `null` once
/// [maxAttempts] delays have been handed out: time to give up. [reset]
/// starts over, for example after a successful connection.
class Backoff {
  /// Creates a backoff sequence.
  Backoff({
    this.initial = const Duration(seconds: 1),
    this.max = const Duration(seconds: 30),
    this.maxAttempts = 6,
  }) : assert(maxAttempts >= 0, 'maxAttempts must not be negative');

  /// The first delay.
  final Duration initial;

  /// The longest delay.
  final Duration max;

  /// How many delays [next] hands out before it returns `null`.
  final int maxAttempts;

  int _issued = 0;
  Duration _delay = Duration.zero;

  /// The delay before the next attempt, or `null` once [maxAttempts] delays
  /// have been issued since the last [reset].
  Duration? next() {
    if (_issued >= maxAttempts) return null;
    _delay = _issued == 0
        ? initial
        : Duration(microseconds: _delay.inMicroseconds * 2);
    if (_delay > max) _delay = max;
    _issued++;
    return _delay;
  }

  /// Restarts the sequence at [initial].
  void reset() {
    _issued = 0;
    _delay = Duration.zero;
  }
}
