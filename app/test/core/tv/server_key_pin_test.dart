import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/tv/server_key_pin.dart';

void main() {
  test('pin_is_lower_case_hex_of_32_bytes', () {
    final key = <int>[0xAB, 0x01, for (var i = 0; i < 30; i++) 0x0F];
    final pin = serverKeyPinFromSha256(key);
    expect(pin, startsWith('ab01'));
    expect(pin, hasLength(64));
    expect(pin, '${'ab01'}${'0f' * 30}');
    expect(
      () => serverKeyPinFromSha256(List<int>.filled(31, 1)),
      throwsArgumentError,
    );
    expect(
      () => serverKeyPinFromSha256(List<int>.filled(33, 1)),
      throwsArgumentError,
    );
  });

  test('pin_comparison_is_case_insensitive_and_null_safe', () {
    final key = <int>[for (var i = 0; i < 32; i++) 0xAB];
    expect(matchesServerKeyPin(key, 'ab' * 32), isTrue);
    expect(matchesServerKeyPin(key, 'AB' * 32), isTrue);
    expect(matchesServerKeyPin(key, 'ac' * 32), isFalse);
    expect(matchesServerKeyPin(key, null), isFalse);
    expect(matchesServerKeyPin(List<int>.filled(31, 0xAB), 'ab' * 32), isFalse);
  });
}
