/// This app's version, known at compile time. It must equal the `version` in
/// `pubspec.yaml` (without the build number); a test holds it there.
///
/// It is reported to the TV and decides the update gate on the first frame,
/// with no wait for the platform's package info (Ruling P7-R8).
const String kAppVersion = '1.0.0';

/// Reads a version such as `1.2.3`, `1.2` (the same as `1.2.0`) or
/// `1.2.3+4` (the build suffix is ignored).
///
/// Anything else, such as a pre-release tag, an empty text or a single
/// number, gives `null`.
({int major, int minor, int patch})? parseAppVersion(String text) {
  final match = _version.firstMatch(text.trim());
  if (match == null) return null;
  final major = int.tryParse(match.group(1)!);
  final minor = int.tryParse(match.group(2)!);
  final patch = int.tryParse(match.group(3) ?? '0');
  if (major == null || minor == null || patch == null) return null;
  return (major: major, minor: minor, patch: patch);
}

final _version = RegExp(r'^(\d{1,9})\.(\d{1,9})(?:\.(\d{1,9}))?(?:\+.*)?$');

/// Whether [current] is older than [minimum].
///
/// `false` whenever either doesn't parse: a malformed setting never blocks
/// anyone.
bool isBelowMinimum(String current, String minimum) {
  final have = parseAppVersion(current);
  final need = parseAppVersion(minimum);
  if (have == null || need == null) return false;
  if (have.major != need.major) return have.major < need.major;
  if (have.minor != need.minor) return have.minor < need.minor;
  return have.patch < need.patch;
}
