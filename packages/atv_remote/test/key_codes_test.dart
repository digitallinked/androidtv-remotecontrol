import 'dart:io';

import 'package:atv_remote/atv_remote.dart';
import 'package:atv_remote/src/cli/key_names.dart';
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

  test('named_lists_every_static_key_constant', () {
    // Run from the package root, as `flutter test` does.
    final source = File('lib/src/key_codes.dart').readAsStringSync();
    final constants = {
      for (final m in RegExp(
        r'static const (?:int )?(\w+) = (\d+);',
      ).allMatches(source))
        m.group(1)!: int.parse(m.group(2)!),
    };
    expect(constants, hasLength(greaterThan(30)), reason: 'the scan works');
    expect(
      KeyCodes.named,
      unorderedEquals(constants.values),
      reason: 'every constant (the digits are a method) is in named',
    );

    // And by name, in declaration order, so two constants with the same
    // value can't stand in for each other.
    final list = RegExp(
      r'static const List<int> named = \[([^\]]*)\]',
    ).firstMatch(source);
    expect(list, isNotNull, reason: 'the named list was found');
    final listed = RegExp(r'\w+').allMatches(list!.group(1)!).map((m) => m[0]);
    expect(listed, orderedEquals(constants.keys));
  });

  test('cli_key_names_cover_named_exactly', () {
    expect(cliKeyCodes.values.toSet(), KeyCodes.named.toSet());
    expect(cliKeyCodes, hasLength(KeyCodes.named.length));
  });
}
