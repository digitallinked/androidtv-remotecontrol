final RegExp _packageName = RegExp(
  r'^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$',
);

/// Whether [s] is a valid Android application id: at least two dot-separated
/// segments, each starting with a letter, and at most 255 characters.
bool isValidPackageName(String s) =>
    s.length <= 255 && _packageName.hasMatch(s);

const Set<String> _systemPackages = {
  'android',
  'com.android.systemui',
  'com.android.tv.settings',
  'com.android.vending',
  'com.android.providers.tv',
  'com.google.android.tvlauncher',
  'com.google.android.apps.tv.launcherx',
  'com.google.android.leanbacklauncher',
  'com.google.android.tv.remote.service',
  'com.google.android.backdrop',
  'com.google.android.apps.tv.dreamx',
  'com.google.android.apps.mediashell',
  'com.google.android.katniss',
  'com.google.android.tungsten.setupwraith',
};

const List<String> _systemPrefixes = [
  'com.mediatek.',
  'com.google.android.inputmethod.',
  'com.android.inputmethod.',
  'com.google.android.gms',
  'com.google.android.gsf',
];

/// Whether [package] is a TV system component (launcher, settings, setup,
/// input method, Play services and the like) that never belongs in an app
/// list.
bool isSystemPackage(String package) =>
    _systemPackages.contains(package) ||
    _systemPrefixes.any(package.startsWith) ||
    package.split('.').any((segment) => segment.contains('launcher'));

const Set<String> _genericSegments = {
  'com',
  'org',
  'net',
  'tv',
  'android',
  'app',
  'apps',
  'atv',
  'androidtv',
  'mobile',
  'ott',
  'leanback',
  'player',
  'client',
  'prod',
  'release',
  'livingroom',
};

/// A readable name for an app that is not in the catalogue: the last segment
/// of [package] that isn't generic (`com`, `tv`, `android` and so on), with
/// `_` as a space and a capital first letter. With nothing left it is
/// [package] itself.
String prettyPackageName(String package) {
  final meaningful = [
    for (final s in package.split('.'))
      if (s.isNotEmpty && !_genericSegments.contains(s.toLowerCase())) s,
  ];
  if (meaningful.isEmpty) return package;
  final words = meaningful.last.replaceAll('_', ' ');
  return words[0].toUpperCase() + words.substring(1);
}
