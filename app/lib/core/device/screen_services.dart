import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

part 'screen_services.g.dart';

/// Keeps the screen on (Ruling P4-R14). Code never calls the plugin directly,
/// so tests can swap in a recorder.
abstract interface class ScreenWakeLock {
  /// Stops the screen from turning off.
  Future<void> enable();

  /// Lets the screen turn off again.
  Future<void> disable();
}

/// [ScreenWakeLock] from the `wakelock_plus` plugin. Platform errors (a
/// missing plugin in a test) are swallowed: a screen that sleeps is never
/// worth failing the remote.
class WakelockPlusScreenWakeLock implements ScreenWakeLock {
  /// Creates the plugin-backed wake lock.
  const WakelockPlusScreenWakeLock();

  @override
  Future<void> enable() => _run(WakelockPlus.enable);

  @override
  Future<void> disable() => _run(WakelockPlus.disable);

  Future<void> _run(Future<void> Function() change) async {
    try {
      await change();
    } on Object {
      // No platform channel: nothing to do.
    }
  }
}

/// Dims the app's screen brightness (Theater Mode, Ruling P4-R14).
abstract interface class ScreenDimmer {
  /// Sets the app's brightness to [brightness], from 0 to 1.
  Future<void> dim(double brightness);

  /// Gives the brightness back to the system setting.
  Future<void> restore();
}

/// [ScreenDimmer] from the `screen_brightness` plugin. It only changes the
/// brightness of this app's window; the system setting is left alone.
/// Platform errors are swallowed.
class ScreenBrightnessDimmer implements ScreenDimmer {
  /// Creates the plugin-backed dimmer.
  const ScreenBrightnessDimmer();

  @override
  Future<void> dim(double brightness) => _run(
    () => ScreenBrightness.instance.setApplicationScreenBrightness(brightness),
  );

  @override
  Future<void> restore() =>
      _run(ScreenBrightness.instance.resetApplicationScreenBrightness);

  Future<void> _run(Future<void> Function() change) async {
    try {
      await change();
    } on Object {
      // No platform channel: nothing to do.
    }
  }
}

/// The app's [ScreenWakeLock]; tests override it with a recorder.
@Riverpod(keepAlive: true)
ScreenWakeLock screenWakeLock(Ref ref) => const WakelockPlusScreenWakeLock();

/// The app's [ScreenDimmer]; tests override it with a recorder.
@Riverpod(keepAlive: true)
ScreenDimmer screenDimmer(Ref ref) => const ScreenBrightnessDimmer();
