import 'package:flutter/foundation.dart';
// Flutter re-exports package:characters here, so the app needs no extra
// dependency for grapheme clusters.
import 'package:flutter/widgets.dart' show StringCharacters;

/// How typed text reaches the TV (Ruling P4-R12).
enum ImeTextMode {
  /// Every change sends the whole field; the TV replaces its field's text.
  replaceField,

  /// Only the new suffix is sent, with `KEYCODE_DEL` for deletions.
  appendOnly,
}

/// (unverified) See Ruling P4-R12: androidtvremote2's `send_text` appears to
/// send the whole field, so the default replaces it. Switch to
/// [ImeTextMode.appendOnly] only if the real-device run shows duplicated text.
const ImeTextMode kImeTextMode = ImeTextMode.replaceField;

/// One step that brings the TV's text field in line with the phone's.
@immutable
sealed class TextEdit {
  const TextEdit();
}

/// Send [text] to the TV's text field.
final class SendText extends TextEdit {
  /// Creates the edit.
  const SendText(this.text);

  /// What to send.
  final String text;

  @override
  bool operator ==(Object other) => other is SendText && other.text == text;

  @override
  int get hashCode => Object.hash(SendText, text);

  // Typed text must never reach logs or failure messages.
  @override
  String toString() => 'SendText(${text.length} code units)';
}

/// Press backspace [count] times.
final class DeleteChars extends TextEdit {
  /// Creates the edit.
  const DeleteChars(this.count);

  /// How many grapheme clusters to delete.
  final int count;

  @override
  bool operator ==(Object other) =>
      other is DeleteChars && other.count == count;

  @override
  int get hashCode => Object.hash(DeleteChars, count);

  @override
  String toString() => 'DeleteChars($count)';
}

/// The steps that turn the text the TV was last given ([sent]) into [next].
///
/// [ImeTextMode.replaceField]: nothing when unchanged, otherwise the whole of
/// [next] (including `''`). [ImeTextMode.appendOnly]: backspaces for what
/// changed after the common prefix, then the rest of [next]; lengths are
/// grapheme clusters, so an emoji with a skin tone, a ZWJ sequence or a
/// letter with a combining mark is one backspace. (unverified) That matches
/// how a TV's backspace deletes: the real-device run checks it.
List<TextEdit> planTextEdit({
  required String sent,
  required String next,
  ImeTextMode mode = kImeTextMode,
}) {
  if (next == sent) return const [];
  switch (mode) {
    case ImeTextMode.replaceField:
      return [SendText(next)];
    case ImeTextMode.appendOnly:
      final before = sent.characters.toList();
      final after = next.characters.toList();
      var prefix = 0;
      while (prefix < before.length &&
          prefix < after.length &&
          before[prefix] == after[prefix]) {
        prefix++;
      }
      final removed = before.length - prefix;
      final rest = after.skip(prefix).join();
      return [
        if (removed > 0) DeleteChars(removed),
        if (rest.isNotEmpty) SendText(rest),
      ];
  }
}
