import 'package:atv_remote/atv_remote.dart';
import 'package:test/test.dart';

void main() {
  test('every_named_key_code_and_digit_is_supported', () {
    for (final code in [
      ...KeyCodes.named,
      for (var d = 0; d <= 9; d++) KeyCodes.digit(d),
    ]) {
      expect(isSupportedKeyCode(code), isTrue, reason: '$code');
    }
    expect(
      KeyCodes.named,
      containsAll([KeyCodes.enter, KeyCodes.delete, KeyCodes.power]),
    );
    expect(KeyCodes.named.toSet(), hasLength(KeyCodes.named.length));
  });

  test('unknown_codes_are_not_supported', () {
    for (final code in [-1, 9999]) {
      expect(isSupportedKeyCode(code), isFalse, reason: '$code');
    }
  });

  test('enter_and_delete_have_the_android_values', () {
    expect(KeyCodes.enter, 66);
    expect(KeyCodes.delete, 67);
  });
}
