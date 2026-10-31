import 'package:flutter/services.dart';
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

/// [ScreenWakeLock] from the `wakelock_plus` plugin.
///
/// The plugin answers over a Pigeon channel, which fails with a
/// [PlatformException] (`channel-error` when no platform side is there, as
/// in a host test, or the error the platform reports). A
/// [MissingPluginException] means a platform without the plugin. Both are
/// tolerated: a screen that sleeps is never worth failing the remote.
/// Anything else is a bug and propagates.
class WakelockPlusScreenWakeLock implements ScreenWakeLock {
  /// Creates the plugin-backed wake lock. Tests may pass their own `toggle`
  /// in place of `WakelockPlus.toggle`.
  const WakelockPlusScreenWakeLock({
    this._toggle = WakelockPlus.toggle,
  });

  final Future<void> Function({required bool enable}) _toggle;

  @override
  Future<void> enable() => _tolerated(() => _toggle(enable: true));

  @override
  Future<void> disable() => _tolerated(() => _toggle(enable: false));
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
///
/// The plugin's method channel fails with a [PlatformException] (for
/// example Android's "no activity", code -10) or, with no platform side, a
/// [MissingPluginException]. Both are tolerated, as for the wake lock. The
/// plugin checks the brightness range in Dart and throws a [RangeError]
/// outside 0 to 1: a bug, so it propagates, like anything else unexpected.
class ScreenBrightnessDimmer implements ScreenDimmer {
  /// Creates the plugin-backed dimmer. Tests may pass their own `plugin` in
  /// place of `ScreenBrightness.instance`.
  const ScreenBrightnessDimmer({this._plugin});

  final ScreenBrightness? _plugin;

  ScreenBrightness get _brightness => _plugin ?? ScreenBrightness.instance;

  @override
  Future<void> dim(double brightness) => _tolerated(
    () => _brightness.setApplicationScreenBrightness(brightness),
  );

  @override
  Future<void> restore() =>
      _tolerated(_brightness.resetApplicationScreenBrightness);
}

/// Runs a plugin [call], tolerating a platform that can't do it.
Future<void> _tolerated(Future<void> Function() call) async {
  try {
    await call();
  } on PlatformException {
    // The platform side failed or isn't there: nothing to do.
  } on MissingPluginException {
    // No plugin on this platform: nothing to do.
  }
}

/// The app's [ScreenWakeLock]; tests override it with a recorder.
@Riverpod(keepAlive: true)
ScreenWakeLock screenWakeLock(Ref ref) => const WakelockPlusScreenWakeLock();

/// The app's [ScreenDimmer]; tests override it with a recorder.
@Riverpod(keepAlive: true)
ScreenDimmer screenDimmer(Ref ref) => const ScreenBrightnessDimmer();
