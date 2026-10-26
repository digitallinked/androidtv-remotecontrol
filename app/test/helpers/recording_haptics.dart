import 'package:tv_remote/core/haptics/haptics.dart';

/// A [Haptics] that records what was requested instead of vibrating.
class RecordingHaptics implements Haptics {
  /// The requests in order: `light`, `medium` or `heavy`.
  final List<String> events = [];

  @override
  Future<void> light() async => events.add('light');

  @override
  Future<void> medium() async => events.add('medium');

  @override
  Future<void> heavy() async => events.add('heavy');
}
