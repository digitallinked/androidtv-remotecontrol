import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';
import 'package:tv_remote/features/apps/domain/name_search.dart';

/// The region marker for apps offered everywhere.
const String kAllRegions = '*';

final RegExp _regionCode = RegExp(r'^[A-Z]{2}$');

/// One app in the bundled catalogue.
///
/// Brand names are data, not UI strings. The catalogue carries no icons and no
/// brand colours (Ruling P5-R4).
@immutable
class CatalogueApp {
  /// Creates a catalogue app.
  const CatalogueApp({
    required this.package,
    required this.name,
    required this.regions,
    this.launchLink,
  });

  /// The Android application id, for example `com.netflix.ninja`.
  final String package;

  /// The name shown to the user.
  final String name;

  /// An explicit launch link; `null` means `market://launch?id=<package>`.
  final String? launchLink;

  /// The upper-case ISO country codes this app is offered in, or `{'*'}`.
  final Set<String> regions;

  /// This app as a shortcut-ready entry (never custom, never with an icon).
  AppEntry toEntry() =>
      AppEntry(package: package, name: name, launchLink: launchLink);

  /// Whether the app is offered in [region]: it is global, or [region] is
  /// listed. A `null` region matches only global apps.
  bool isAvailableIn(String? region) =>
      regions.contains(kAllRegions) ||
      (region != null && regions.contains(region.toUpperCase()));

  @override
  String toString() => 'CatalogueApp($package)';
}

/// The bundled app catalogue and its per-region default rows.
@immutable
class AppCatalogue {
  const AppCatalogue._(this.apps, this.defaultRows, this._byPackage);

  /// Parses the catalogue JSON.
  ///
  /// Throws a [FormatException] for a missing or empty field, a duplicate
  /// package, a region that is neither `*` nor two upper-case letters, a
  /// default-row package that is not in [apps], a row that is not exactly
  /// [rowLength] long or repeats a package, a missing `*` row, a `version`
  /// other than 1, or any key the schema does not define (so an icon URL or a
  /// colour can never slip in unnoticed; Ruling P5-R4).
  factory AppCatalogue.parse(String json) {
    final Object? root;
    try {
      root = jsonDecode(json);
    } on FormatException {
      throw const FormatException('The catalogue is not valid JSON.');
    }
    if (root is! Map<String, Object?>) {
      throw const FormatException('The catalogue must be a JSON object.');
    }

    _onlyKeys(root, _topKeys, 'catalogue');
    if (root['version'] != schemaVersion) {
      throw const FormatException('Unsupported catalogue version.');
    }

    final rawApps = _list(root['apps'], 'apps');
    if (rawApps.isEmpty) {
      throw const FormatException('The catalogue has no apps.');
    }
    final apps = <CatalogueApp>[];
    final byPackage = <String, CatalogueApp>{};
    for (final raw in rawApps) {
      final app = _parseApp(raw);
      if (byPackage.containsKey(app.package)) {
        throw FormatException('Duplicate package ${app.package}.');
      }
      byPackage[app.package] = app;
      apps.add(app);
    }

    final rawRows = root['defaultRows'];
    if (rawRows is! Map<String, Object?>) {
      throw const FormatException('Missing defaultRows.');
    }
    final rows = <String, List<String>>{};
    for (final MapEntry(:key, :value) in rawRows.entries) {
      if (key != kAllRegions && !_regionCode.hasMatch(key)) {
        throw FormatException('Bad region "$key" in defaultRows.');
      }
      final packages = [
        for (final p in _list(value, 'defaultRows.$key')) _string(p, key),
      ];
      if (packages.length != rowLength ||
          packages.toSet().length != rowLength) {
        throw FormatException(
          'Row "$key" must have $rowLength different apps.',
        );
      }
      for (final p in packages) {
        if (!byPackage.containsKey(p)) {
          throw FormatException('Row "$key" has unknown package $p.');
        }
      }
      rows[key] = List.unmodifiable(packages);
    }
    if (!rows.containsKey(kAllRegions)) {
      throw const FormatException('defaultRows has no "*" row.');
    }
    return AppCatalogue._(
      List.unmodifiable(apps),
      Map.unmodifiable(rows),
      Map.unmodifiable(byPackage),
    );
  }

  /// The only catalogue format version this build reads.
  static const int schemaVersion = 1;

  static const Set<String> _topKeys = {'version', 'apps', 'defaultRows'};
  static const Set<String> _appKeys = {
    'package',
    'name',
    'regions',
    'launchLink',
  };

  /// How many apps every default row holds.
  static const int rowLength = 6;

  /// Every app, in catalogue order.
  final List<CatalogueApp> apps;

  /// Default shortcut packages by upper-case region code, plus `*`.
  final Map<String, List<String>> defaultRows;

  final Map<String, CatalogueApp> _byPackage;

  /// The app with [package], or `null`.
  CatalogueApp? byPackage(String package) => _byPackage[package];

  /// The default shortcuts for [region] (any case), or the `*` row when the
  /// region is `null` or has no row of its own.
  List<AppEntry> defaultShortcutsFor(String? region) {
    final row = defaultRows[region?.toUpperCase()] ?? defaultRows[kAllRegions]!;
    return [for (final p in row) _byPackage[p]!.toEntry()];
  }

  /// Apps worth suggesting: those listed for [region] (catalogue order), then
  /// the global ones, without duplicates.
  List<CatalogueApp> suggestedFor(String? region) {
    final code = region?.toUpperCase();
    return [
      if (code != null)
        for (final a in apps)
          if (!a.regions.contains(kAllRegions) && a.regions.contains(code)) a,
      for (final a in apps)
        if (a.regions.contains(kAllRegions)) a,
    ];
  }

  /// Apps whose name or package contains [query], ignoring case; none for a
  /// blank query.
  ///
  /// They are ordered by [nameMatchRank] (a name that starts with the query
  /// first, then a later word that does, then any other match; Ruling
  /// P7-R10), then the apps offered in [region] before the others, then
  /// catalogue order.
  List<CatalogueApp> search(String query, {String? region}) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) {
      return const [];
    }
    final ranked = [
      for (final a in apps)
        if (a.name.toLowerCase().contains(needle) ||
            a.package.toLowerCase().contains(needle))
          (app: a, rank: nameMatchRank(a.name, needle)),
    ];
    return [
      for (var rank = 0; rank <= kNoNameMatch; rank++)
        for (final available in const [true, false])
          for (final hit in ranked)
            if (hit.rank == rank && hit.app.isAvailableIn(region) == available)
              hit.app,
    ];
  }

  static CatalogueApp _parseApp(Object? raw) {
    if (raw is! Map<String, Object?>) {
      throw const FormatException('An app entry must be an object.');
    }
    _onlyKeys(raw, _appKeys, 'app entry');
    final package = _string(raw['package'], 'package');
    final name = _string(raw['name'], '$package name');
    final link = raw['launchLink'];
    if (link != null && (link is! String || link.trim().isEmpty)) {
      throw FormatException('Bad launchLink for $package.');
    }
    final regions = <String>{
      for (final r in _list(raw['regions'], '$package regions'))
        _region(_string(r, '$package region'), package),
    };
    if (regions.isEmpty) {
      throw FormatException('$package has no regions.');
    }
    return CatalogueApp(
      package: package,
      name: name,
      launchLink: link as String?,
      regions: Set.unmodifiable(regions),
    );
  }

  static void _onlyKeys(
    Map<String, Object?> map,
    Set<String> allowed,
    String what,
  ) {
    for (final key in map.keys) {
      if (!allowed.contains(key)) {
        throw FormatException('Unknown key "$key" in $what.');
      }
    }
  }

  static String _region(String region, String package) {
    if (region != kAllRegions && !_regionCode.hasMatch(region)) {
      throw FormatException('Bad region "$region" for $package.');
    }
    return region;
  }

  static List<Object?> _list(Object? value, String field) {
    if (value is! List<Object?>) {
      throw FormatException('Missing list "$field".');
    }
    return value;
  }

  static String _string(Object? value, String field) {
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Missing or empty "$field".');
    }
    return value;
  }
}
