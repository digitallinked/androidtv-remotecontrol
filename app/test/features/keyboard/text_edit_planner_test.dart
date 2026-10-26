// The explicit mode keeps these tests independent of kImeTextMode.
// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/features/keyboard/text_edit_planner.dart';

void main() {
  test('replace_mode_sends_the_whole_field', () {
    expect(
      planTextEdit(sent: 'hel', next: 'help', mode: ImeTextMode.replaceField),
      [const SendText('help')],
    );
    expect(
      planTextEdit(sent: 'help', next: '', mode: ImeTextMode.replaceField),
      [const SendText('')],
    );
  });

  test('replace_mode_sends_nothing_when_unchanged', () {
    expect(
      planTextEdit(sent: 'abc', next: 'abc', mode: ImeTextMode.replaceField),
      isEmpty,
    );
    expect(
      planTextEdit(sent: '', next: '', mode: ImeTextMode.replaceField),
      isEmpty,
    );
  });

  test('default_mode_is_replace_field', () {
    expect(kImeTextMode, ImeTextMode.replaceField);
    expect(planTextEdit(sent: 'a', next: 'ab'), [const SendText('ab')]);
  });

  test('append_mode_deletes_then_sends_the_new_suffix', () {
    expect(
      planTextEdit(sent: 'hello', next: 'help', mode: ImeTextMode.appendOnly),
      [const DeleteChars(2), const SendText('p')],
    );
    expect(
      planTextEdit(sent: 'ab', next: 'abc', mode: ImeTextMode.appendOnly),
      [const SendText('c')],
    );
    expect(
      planTextEdit(sent: 'abc', next: 'ab', mode: ImeTextMode.appendOnly),
      [const DeleteChars(1)],
    );
    expect(
      planTextEdit(sent: 'abc', next: 'abc', mode: ImeTextMode.appendOnly),
      isEmpty,
    );
    expect(
      planTextEdit(sent: 'abc', next: 'xy', mode: ImeTextMode.appendOnly),
      [const DeleteChars(3), const SendText('xy')],
    );
  });

  test('append_mode_counts_graphemes', () {
    expect(
      planTextEdit(sent: 'a👍🏽', next: 'a', mode: ImeTextMode.appendOnly),
      [const DeleteChars(1)],
    );
    expect(
      planTextEdit(sent: 'a', next: 'a👍🏽', mode: ImeTextMode.appendOnly),
      [const SendText('👍🏽')],
    );
  });

  test('edits_compare_by_value_and_never_print_the_text', () {
    expect(const SendText('a'), const SendText('a'));
    expect(const SendText('a').hashCode, const SendText('a').hashCode);
    expect(const SendText('a'), isNot(const SendText('b')));
    expect(const DeleteChars(2), const DeleteChars(2));
    expect(const DeleteChars(2), isNot(const DeleteChars(3)));
    expect(const SendText('secret').toString(), isNot(contains('secret')));
  });
}
