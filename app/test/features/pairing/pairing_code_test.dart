import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/features/pairing/domain/pairing_code.dart';

void main() {
  test('normalises_case_whitespace_and_separators', () {
    for (final raw in [' ab12cd\n', 'AB-12-CD', 'ab 12 cd', 'aB12cD9F']) {
      expect(normalizePairingCode(raw), 'AB12CD');
    }
    expect(normalizePairingCode('zz12'), '12');
    expect(isCompletePairingCode('AB12CD'), isTrue);
    expect(isCompletePairingCode('AB12C'), isFalse);
  });

  test('only_exactly_six_upper_case_hex_characters_are_complete', () {
    expect(isCompletePairingCode('AB12CDE'), isFalse);
    expect(isCompletePairingCode('ab12cd'), isFalse);
    expect(isCompletePairingCode('AB12CG'), isFalse);
    expect(isCompletePairingCode('AB12CD\n'), isFalse);
    expect(isCompletePairingCode(''), isFalse);
  });

  test('formatter_normalises_and_puts_the_caret_at_the_end', () {
    final result = PairingCodeFormatter().formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(
        text: 'ab-12 cd9',
        selection: TextSelection.collapsed(offset: 2),
      ),
    );
    expect(result.text, 'AB12CD');
    expect(result.selection, const TextSelection.collapsed(offset: 6));
  });
}
