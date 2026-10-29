/// How well an app's name matches a search (Ruling P7-R10).
library;

/// The rank of a search hit that matches on something other than the name,
/// such as the package.
const int kNoNameMatch = 3;

/// The characters that separate the words of a name, besides whitespace.
const String _wordSeparators = '-+:&.';

final RegExp _whitespace = RegExp(r'\s');

bool _isSeparator(String char) =>
    _wordSeparators.contains(char) || _whitespace.hasMatch(char);

/// How well [name] matches [needle], ignoring case; lower is better.
///
/// The needle is trimmed and lower-cased. The rank is:
/// - `0` when the name starts with the needle;
/// - `1` when a later word of the name starts with it (words are split on
///   whitespace and `-+:&.`, so a needle may also span words);
/// - `2` when the name contains it anywhere else;
/// - [kNoNameMatch] (`3`) when the name does not contain it.
///
/// A blank needle ranks `0`: every name starts with it.
int nameMatchRank(String name, String needle) {
  final n = needle.trim().toLowerCase();
  final s = name.toLowerCase();
  if (s.startsWith(n)) return 0;
  var contains = false;
  for (var i = s.indexOf(n, 1); i > 0; i = s.indexOf(n, i + 1)) {
    if (_isSeparator(s[i - 1]) && !_isSeparator(s[i])) return 1;
    contains = true;
  }
  return contains ? 2 : kNoNameMatch;
}
