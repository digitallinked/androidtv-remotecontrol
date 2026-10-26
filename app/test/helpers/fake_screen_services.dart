import 'package:tv_remote/core/device/screen_services.dart';

/// A [ScreenWakeLock] that records the changes instead of touching the
/// platform.
class RecordingWakeLock implements ScreenWakeLock {
  /// Whether the screen is currently kept on.
  bool enabled = false;

  /// Every `enable` (true) and `disable` (false) call, in order.
  final List<bool> changes = [];

  @override
  Future<void> enable() async {
    enabled = true;
    changes.add(true);
  }

  @override
  Future<void> disable() async {
    enabled = false;
    changes.add(false);
  }
}

/// A [ScreenDimmer] that records the requests instead of touching the
/// platform.
class RecordingDimmer implements ScreenDimmer {
  /// The brightness the app is dimmed to, or null while it is not dimmed.
  double? level;

  /// How many times the brightness was restored.
  int restores = 0;

  @override
  Future<void> dim(double brightness) async => level = brightness;

  @override
  Future<void> restore() async {
    level = null;
    restores++;
  }
}
