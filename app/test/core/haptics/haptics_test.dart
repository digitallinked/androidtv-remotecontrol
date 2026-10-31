import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/haptics/haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('platform_haptics_call_the_right_feedback_type', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String>[];
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add('${call.method} ${call.arguments}');
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    const haptics = PlatformHaptics();
    // One at a time, so a swapped pair can't hide in a list.
    for (final (feedback, type) in [
      (haptics.light, 'HapticFeedbackType.lightImpact'),
      (haptics.medium, 'HapticFeedbackType.mediumImpact'),
      (haptics.heavy, 'HapticFeedbackType.heavyImpact'),
    ]) {
      calls.clear();
      await feedback();
      expect(calls, ['HapticFeedback.vibrate $type']);
    }
  });

  testWidgets('platform_haptics_swallow_platform_errors', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => throw PlatformException(code: 'no_vibrator'),
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    const haptics = PlatformHaptics();
    await haptics.light();
    await haptics.medium();
    await haptics.heavy();
  });
}
