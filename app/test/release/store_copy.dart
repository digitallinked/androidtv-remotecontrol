import 'dart:convert';
import 'dart:io';

/// One store-listing field (Ruling P9-R13).
final class StoreField {
  /// A field with its [id], its store limit [max] and its [text].
  const StoreField({required this.id, required this.max, required this.text});

  /// The field id, such as `play.title` or `shot.phone.01`.
  final String id;

  /// The store's character limit for the field.
  final int max;

  /// The field's text, tokens unfilled.
  final String text;
}

/// A field heading: `## <id> (max <n>)`.
final RegExp _heading = RegExp(r'^## (\S+) \(max (\d+)\)$');

/// A `{{TOKEN}}` placeholder.
final RegExp _token = RegExp(r'\{\{([^{}]*)\}\}');

/// Parses a store-listing file (Ruling P9-R13).
///
/// Each field is a `## <id> (max <n>)` heading followed by exactly one
/// fenced `text` block; prose between them is a note and is ignored. Every
/// `## ` line outside a block must be a field heading. Throws
/// [FormatException] on a malformed heading, a heading without exactly one
/// block, a block outside a field, an unclosed block or a duplicate id.
Map<String, StoreField> parseStoreCopy(String markdown) {
  final lines = markdown.replaceAll('\r\n', '\n').split('\n');
  final fields = <String, StoreField>{};
  String? id;
  var max = 0;
  final blocks = <String>[];

  void finish() {
    if (id == null) return;
    if (blocks.length != 1) {
      throw FormatException(
        '$id has ${blocks.length} text blocks; it needs exactly one',
      );
    }
    if (fields.containsKey(id)) throw FormatException('duplicate id $id');
    fields[id] = StoreField(id: id, max: max, text: blocks.single);
  }

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.startsWith('```')) {
      if (line.trimRight() != '```text') {
        throw FormatException('line ${i + 1}: only text blocks are allowed');
      }
      if (id == null) {
        throw FormatException('line ${i + 1}: a text block outside a field');
      }
      final end = lines.indexWhere((l) => l.trimRight() == '```', i + 1);
      if (end < 0) throw FormatException('line ${i + 1}: unclosed text block');
      blocks.add(lines.sublist(i + 1, end).join('\n'));
      i = end;
      continue;
    }
    if (line.startsWith('## ')) {
      final match = _heading.firstMatch(line.trimRight());
      if (match == null) {
        throw FormatException('line ${i + 1}: not a field heading: $line');
      }
      finish();
      id = match[1];
      max = int.parse(match[2]!);
      blocks.clear();
    }
  }
  finish();
  return fields;
}

/// Replaces each `{{TOKEN}}` in [text] with its value in [values]; unknown
/// tokens and tokens whose value is `null` stay as written (P9-R13 counts
/// them as their `{{TOKEN}}` text).
String fillTokens(String text, Map<String, String?> values) =>
    text.replaceAllMapped(_token, (m) => values[m[1]] ?? m[0]!);

/// The `value` of each token in `docs/release/placeholders.json`.
Map<String, String?> placeholderValues() {
  final decoded =
      jsonDecode(File('../docs/release/placeholders.json').readAsStringSync())
          as Map<String, Object?>;
  return {
    for (final MapEntry(:key, :value) in decoded.entries)
      key: (value! as Map<String, Object?>)['value'] as String?,
  };
}

/// The store copy for [locale].
Map<String, StoreField> loadStoreCopy(String locale) => parseStoreCopy(
  File('../docs/release/store-listing/$locale.md').readAsStringSync(),
);
