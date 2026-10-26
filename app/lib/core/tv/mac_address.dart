final RegExp _pairs = RegExp(
  r'^[0-9A-Fa-f]{2}([:-])[0-9A-Fa-f]{2}(\1[0-9A-Fa-f]{2}){4}$',
);
final RegExp _quads = RegExp(
  r'^[0-9A-Fa-f]{4}\.[0-9A-Fa-f]{4}\.[0-9A-Fa-f]{4}$',
);
final RegExp _bare = RegExp(r'^[0-9A-Fa-f]{12}$');

/// Reads a MAC address typed by a person and returns it as upper-case
/// `AA:BB:CC:DD:EE:FF`, or `null` when it isn't one a TV could have.
///
/// Accepts 12 hex digits written with `:` or `-` between pairs, `.` between
/// groups of four (`aabb.ccdd.eeff`), or no separators, around optional
/// spaces. Rejects all zeros, the broadcast address and multicast addresses
/// (the low bit of the first octet set): none of them is a device.
String? parseMac(String input) {
  final text = input.trim();
  if (!_pairs.hasMatch(text) &&
      !_quads.hasMatch(text) &&
      !_bare.hasMatch(text)) {
    return null;
  }
  final digits = text.replaceAll(RegExp('[:.-]'), '').toUpperCase();
  final first = int.parse(digits.substring(0, 2), radix: 16);
  if (first.isOdd || RegExp(r'^0+$').hasMatch(digits)) return null;
  return [
    for (var i = 0; i < 12; i += 2) digits.substring(i, i + 2),
  ].join(':');
}
