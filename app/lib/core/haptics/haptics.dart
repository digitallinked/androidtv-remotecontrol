import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'haptics.g.dart';

/// Haptic feedback for remote presses (Ruling P4-R6).
///
/// The only way the app vibrates: code never calls `HapticFeedback`
/// directly, so tests can swap in a recorder.
abstract interface class Haptics {
  /// A sent tap, a touchpad step, an app launch.
  Future<void> light();

  /// A hold start.
  Future<void> medium();

  /// The power action.
  Future<void> heavy();
}

/// [Haptics] from the platform's impact feedback. Platform errors (a device
/// without a vibrator, a missing plugin in a test) are swallowed: feedback is
/// never worth failing a press.
class PlatformHaptics implements Haptics {
  /// Creates the platform haptics.
  const PlatformHaptics();

  @override
  Future<void> light() => _run(HapticFeedback.lightImpact);

  @override
  Future<void> medium() => _run(HapticFeedback.mediumImpact);

  @override
  Future<void> heavy() => _run(HapticFeedback.heavyImpact);

  Future<void> _run(Future<void> Function() impact) async {
    try {
      await impact();
    } on Object {
      // No vibrator or no platform channel: nothing to do.
    }
  }
}

/// The app's [Haptics]; tests override it with a recorder.
@Riverpod(keepAlive: true)
Haptics haptics(Ref ref) => const PlatformHaptics();
