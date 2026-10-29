import 'package:flutter/widgets.dart';

/// Android 14's non-linear 200% font curve: small text grows by 2x, large
/// text by less (8 -> 16, 10 -> 20, 12 -> 24, 14 -> 26, 18 -> 30, 20 -> 34,
/// 24 -> 36, 30 -> 38, 100 -> 100, interpolated between them).
class NonlinearTwoXScaler extends TextScaler {
  /// Creates the scaler.
  const NonlinearTwoXScaler();

  static const List<double> _from = [8, 10, 12, 14, 18, 20, 24, 30, 100];
  static const List<double> _to = [16, 20, 24, 26, 30, 34, 36, 38, 100];

  @override
  double scale(double fontSize) {
    if (fontSize <= _from.first) return fontSize * 2;
    for (var i = 1; i < _from.length; i++) {
      if (fontSize <= _from[i]) {
        final f = (fontSize - _from[i - 1]) / (_from[i] - _from[i - 1]);
        return _to[i - 1] + f * (_to[i] - _to[i - 1]);
      }
    }
    return fontSize;
  }

  @override
  double get textScaleFactor => 2;

  @override
  bool operator ==(Object other) => other is NonlinearTwoXScaler;

  @override
  int get hashCode => 2;
}
