/// The name of each supported language in that language (its endonym), by
/// language code.
///
/// These are data, not UI strings: a language is always named in itself, so a
/// reader who landed in the wrong one can still find theirs (Ruling P5-R11).
/// A code that isn't listed is shown as the code itself.
const Map<String, String> kLanguageNames = {
  'en': 'English',
  'ms': 'Bahasa Melayu',
};

/// The name to show for the language [code].
String languageName(String code) => kLanguageNames[code] ?? code;
