/// Removes what could identify a TV, a network or the user from error text
/// before it leaves the phone (Ruling P6-R5).
///
/// The rules run in a fixed order, each on the output of the one before:
///
/// 1. PEM blocks (also a truncated one) become `<pem>`.
/// 2. UUIDs become `<id>`.
/// 3. Long base64 runs that mix digits and both letter cases become `<b64>`.
/// 4. Links that can carry typed text or a package name (`mailto:`,
///    `market:`, `intent:`, `tel:`, `sms:`) become `<uri>`.
/// 5. The saved TVs' names (a `%20` or `+` counts as a space) become `<tv>`.
///    This runs before the route-path and service-name rules so that a saved
///    name with a quote or a bracket is removed whole.
/// 6. The TV segment of a route path (`/pair/<name>`, `/devices/<name>`)
///    becomes `<tv>`: it holds the TV's name URL-encoded, which the
///    saved-name rule can't match, and a discovered TV isn't saved at all.
/// 7. mDNS service names (with the whole instance label before them) and
///    `*.local` host names become `<host>`.
/// 8. `manual:<address>` entries become `<tv>`.
/// 9. E-mail addresses become `<email>`.
/// 10. MAC addresses, in `:`, `-`, dotted and bare form, become `<mac>`.
/// 11. IPv6 addresses (valid forms, then any run of four or more hex groups
///     joined by colons) and IPv4 addresses become `<ip>`.
/// 12. Hex runs of 12 or more characters become `<hex>`.
/// 13. 6-character hex tokens that contain a digit (pairing codes) become
///     `<code>`.
///
/// It prefers removing too much to removing too little: a time such as
/// `12:30:45` is kept, but a plain 6-digit number is not.
class CrashScrubber {
  /// Creates a scrubber. `knownTerms` supplies the saved TVs' display names,
  /// nicknames and service names; it is read on every `scrub`, so the terms
  /// stay current.
  CrashScrubber({this._knownTerms});

  final Iterable<String> Function()? _knownTerms;

  static final _pem = RegExp(
    r'-----BEGIN [A-Z0-9 ]+-----[\s\S]*?(?:-----END [A-Z0-9 ]+-----|$)',
  );
  static final _base64 = RegExp('[A-Za-z0-9+/]{40,}={0,2}');
  static final _uri = RegExp(r'\b(?:mailto|market|intent|tel|sms):\S+');
  // A route location's TV segment. A path inside a file name such as
  // `features/devices/...` is left alone: the slash must not follow a word.
  static final _routePath = RegExp(
    r'''(?<![\w.\-/])(/(?:pair|devices)/)[^\s/?#"'<>()\[\],;]+''',
  );
  // The instance label sits in front of the service type and may hold spaces,
  // quotes, commas and brackets, so up to 63 characters before it (the mDNS
  // limit) go too, stopping only at characters that end a field.
  static final _serviceName = RegExp(
    r'''[^\r\n:;="\[\]<>]{0,63}?\._androidtvremote2?\._tcp(?:\.local)?\.?''',
  );
  static final _uuid = RegExp(
    '(?<![0-9A-Za-z])$_h{8}-$_h{4}-$_h{4}-$_h{4}-$_h{12}(?![0-9A-Za-z])',
  );
  static final _localHost = RegExp(r'[\w-]+(?:\.[\w-]+)*\.local\b');
  static final _manual = RegExp(r'''manual:[^\s,;)\]'"]+''');
  static final _email = RegExp(
    r'[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+',
  );

  static const _h = '[0-9A-Fa-f]';
  static final _mac = RegExp(
    '(?<![0-9A-Za-z])(?:'
    '$_h{2}([:-])(?:$_h{2}\\1){4}$_h{2}'
    '|$_h{4}\\.$_h{4}\\.$_h{4}'
    '|$_h{12}'
    ')(?![0-9A-Za-z])',
  );

  // Valid IPv6 only (8 groups, or `::` once), so durations and times such as
  // `0:00:05` are left alone.
  static const _g = '$_h{1,4}';
  static final _ipv6 = RegExp(
    '(?<![0-9A-Za-z])(?:'
    '$_g(?::$_g){7}'
    '|$_g(?::$_g)*::(?:$_g(?::$_g)*)?'
    '|::$_g(?::$_g)*'
    r')(?:%[0-9A-Za-z_.-]+)?(?![0-9A-Za-z]|\.[0-9])',
  );
  // Anything that still looks like an address: four or more colon-separated
  // hex groups. Three (a time such as `12:34:56`) are left alone.
  static final _ipv6Loose = RegExp(
    '(?<![0-9A-Za-z])$_g(?::$_g){3,}(?:%[0-9A-Za-z_.-]+)?(?![0-9A-Za-z])',
  );
  static final _ipv4 = RegExp(
    r'(?<![0-9.])(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})(?![0-9]|\.[0-9])',
  );
  static final _hexRun = RegExp('$_h{12,}');
  static final _code = RegExp(
    '(?<![0-9A-Za-z.])(?=$_h{0,5}[0-9])$_h{6}(?![0-9A-Za-z])',
  );

  /// [text] with everything identifying replaced by a `<placeholder>`; `''`
  /// for `null`.
  String scrub(String? text) {
    if (text == null || text.isEmpty) return '';
    final out = text
        .replaceAll(_pem, '<pem>')
        .replaceAll(_uuid, '<id>')
        .replaceAllMapped(_base64, (m) {
          final run = m[0]!;
          final mixed =
              run.contains(RegExp('[0-9]')) &&
              run.contains(RegExp('[A-Z]')) &&
              run.contains(RegExp('[a-z]'));
          return mixed ? '<b64>' : run;
        })
        .replaceAll(_uri, '<uri>');
    return _scrubKnownTerms(out)
        .replaceAllMapped(_routePath, (m) => '${m[1]}<tv>')
        .replaceAll(_serviceName, '<host>')
        .replaceAll(_localHost, '<host>')
        .replaceAll(_manual, '<tv>')
        .replaceAll(_email, '<email>')
        .replaceAll(_mac, '<mac>')
        .replaceAll(_ipv6, '<ip>')
        .replaceAll(_ipv6Loose, '<ip>')
        .replaceAllMapped(_ipv4, (m) {
          final valid = [
            for (var i = 1; i <= 4; i++) int.parse(m[i]!),
          ].every((octet) => octet <= 255);
          return valid ? '<ip>' : m[0]!;
        })
        .replaceAll(_hexRun, '<hex>')
        .replaceAll(_code, '<code>');
  }

  String _scrubKnownTerms(String text) {
    final List<String> terms;
    try {
      terms =
          (_knownTerms?.call() ?? const <String>[])
              .map((term) => term.trim())
              .where((term) => term.length >= 3)
              .toSet()
              .toList()
            ..sort((a, b) => b.length.compareTo(a.length));
    } on Object {
      return text;
    }
    if (terms.isEmpty) return text;
    final alternatives = terms.map(_literal).join('|');
    final pattern = RegExp(
      r'(?<![\p{L}\p{N}])(?:'
      '$alternatives'
      r')(?![\p{L}\p{N}])',
      caseSensitive: false,
      unicode: true,
    );
    return text.replaceAll(pattern, '<tv>');
  }

  // Not `RegExp.escape`: it escapes characters that are invalid escapes under
  // the `unicode` flag.
  // Runs of white space match any run of white space, and a URL-encoded or
  // `+` space (route paths carry names that way).
  static String _literal(String term) => term
      .split(RegExp(r'\s+'))
      .map(
        (word) => word.replaceAllMapped(
          RegExp(r'[\\^$.*+?()\[\]{}|]'),
          (m) => '\\${m[0]}',
        ),
      )
      .join(r'(?:\s|%20|\+)+');
}
