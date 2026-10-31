import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:tv_remote/core/device/screen_services.dart';

/// A brightness plugin whose calls throw [error].
class _ThrowingBrightness extends Fake implements ScreenBrightness {
  _ThrowingBrightness(this.error);

  final Object error;

  @override
  Future<void> setApplicationScreenBrightness(double brightness) =>
      Future.error(error);

  @override
  Future<void> resetApplicationScreenBrightness() => Future.error(error);
}

/// A wake-lock toggle that throws [error].
Future<void> Function({required bool enable}) _throwingToggle(Object error) =>
    ({required enable}) => Future.error(error);

const _brightnessChannel = MethodChannel(
  'github.com/aaassseee/screen_brightness',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('unexpected_errors_are_not_swallowed', () async {
    final wakeLock = WakelockPlusScreenWakeLock(
      toggle: _throwingToggle(StateError('bug')),
    );
    await expectLater(wakeLock.enable(), throwsStateError);
    await expectLater(wakeLock.disable(), throwsStateError);

    final dimmer = ScreenBrightnessDimmer(
      plugin: _ThrowingBrightness(StateError('bug')),
    );
    await expectLater(dimmer.dim(0.05), throwsStateError);
    await expectLater(dimmer.restore(), throwsStateError);
  });

  test('an_out_of_range_brightness_is_a_bug_and_propagates', () async {
    // The real plugin checks the range in Dart, before its channel.
    await expectLater(
      const ScreenBrightnessDimmer().dim(2),
      throwsA(isA<RangeError>()),
    );
  });

  test('missing_plugin_is_tolerated', () async {
    // No platform side in a host test: the brightness channel has no handler
    // (MissingPluginException) and the wake lock's Pigeon channel has no
    // host (PlatformException "channel-error").
    await const WakelockPlusScreenWakeLock().enable();
    await const WakelockPlusScreenWakeLock().disable();
    await const ScreenBrightnessDimmer().dim(0.05);
    await const ScreenBrightnessDimmer().restore();

    // And the same through the seams, one exception type at a time.
    for (final error in [
      MissingPluginException('none'),
      PlatformException(code: 'channel-error'),
    ]) {
      await WakelockPlusScreenWakeLock(toggle: _throwingToggle(error)).enable();
      await ScreenBrightnessDimmer(
        plugin: _ThrowingBrightness(error),
      ).dim(0.05);
    }
  });

  test('platform_errors_are_tolerated', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String>[];
    messenger.setMockMethodCallHandler(_brightnessChannel, (call) async {
      calls.add(call.method);
      throw PlatformException(code: '-10', message: 'no activity');
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(_brightnessChannel, null),
    );

    await const ScreenBrightnessDimmer().dim(0.05);
    await const ScreenBrightnessDimmer().restore();
    expect(calls, [
      'setApplicationScreenBrightness',
      'resetApplicationScreenBrightness',
    ]);
  });
}
