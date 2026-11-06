import 'dart:io';
import 'dart:ui';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';
import 'package:tv_remote/features/apps/domain/app_logos.dart';

import '../../helpers/test_catalogue.dart';

/// The cells of the table row of `SOURCES.md` that names [file]: app, package,
/// file, source, version, licence, URL, source colour, ink.
List<String> _sourceRow(String file) {
  final rows = File(
    'assets/app_icons/SOURCES.md',
  ).readAsLinesSync().where((l) => l.contains('| `$file` |')).toList();
  expect(rows, hasLength(1), reason: file);
  final cells = rows.single.split('|');
  return [for (final c in cells.sublist(1, cells.length - 1)) c.trim()];
}

/// The file name of [logo]'s asset.
String _fileOf(AppLogo logo) => logo.asset.split('/').last;

void main() {
  test('every_logo_asset_exists_and_is_declared', () {
    expect(kAppLogos, hasLength(27));
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('- assets/app_icons/'),
    );
    final files = <String>{};
    for (final MapEntry(key: package, value: logo) in kAppLogos.entries) {
      expect(logo.asset, startsWith('assets/app_icons/'), reason: package);
      expect(logo.asset, endsWith('.svg'), reason: package);
      expect(File(logo.asset).existsSync(), isTrue, reason: logo.asset);
      files.add(_fileOf(logo));

      final row = _sourceRow(_fileOf(logo));
      expect(row[1], '`$package`', reason: logo.asset);
      expect(row[5], anyOf('CC0-1.0', 'CC-BY-4.0'), reason: logo.asset);
      expect(row[6], startsWith('https://'), reason: logo.asset);
    }
    expect(files, hasLength(27), reason: 'one file for each app');
    // Nothing is bundled that no tile draws.
    final bundled = Directory('assets/app_icons')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((name) => name != 'SOURCES.md')
        .toSet();
    expect(bundled, files);
  });

  test('every_logo_compiles_from_the_bundle', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final logo in kAppLogos.values) {
      final compiled = await SvgAssetLoader(logo.asset).loadBytes(null);
      expect(compiled.lengthInBytes, greaterThan(0), reason: logo.asset);
    }
  });

  test('every_mapped_package_is_in_the_catalogue', () {
    final catalogue = {for (final a in testCatalogue().apps) a.package};
    for (final package in kAppLogos.keys) {
      expect(catalogue, contains(package));
    }
  });

  test('no_mapped_app_uses_a_network_image', () {
    final network = RegExp(
      r'NetworkImage|Image\.network|SvgPicture\.network|SvgNetworkLoader'
      '|CachedNetworkImage',
    );
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    expect(sources, isNotEmpty);
    for (final file in sources) {
      expect(
        network.hasMatch(file.readAsStringSync()),
        isFalse,
        reason: file.path,
      );
    }
    // A logo file can't reach out either: no linked image, no stylesheet.
    for (final logo in kAppLogos.values) {
      final svg = File(logo.asset).readAsStringSync();
      for (final banned in const ['<image', 'href', 'url(http', '@import']) {
        expect(svg, isNot(contains(banned)), reason: logo.asset);
      }
    }
  });

  test('the_tile_is_the_fixed_dark_neutral', () {
    expect(kAppLogoTile.toARGB32(), 0xFF141414);
  });

  test('every_ink_reads_on_the_tile', () {
    for (final MapEntry(key: package, value: logo) in kAppLogos.entries) {
      expect(logo.fill, kAppLogoTile, reason: package);
      expect(
        contrastRatio(logo.ink, logo.fill),
        greaterThanOrEqualTo(3),
        reason: package,
      );
    }
  });

  test('every_ink_is_the_source_colour_unless_that_is_under_3_to_1', () {
    final hex = RegExp('#([0-9A-F]{6})');
    int argb(String cell) =>
        0xFF000000 | int.parse(hex.firstMatch(cell)![1]!, radix: 16);
    const white = 0xFFFFFFFF;
    for (final logo in kAppLogos.values) {
      final file = _fileOf(logo);
      final row = _sourceRow(file);
      final source = argb(row[7]);
      final readable = contrastRatio(Color(source), kAppLogoTile) >= 3;
      expect(logo.ink.toARGB32(), readable ? source : white, reason: file);
      expect(argb(row[8]), logo.ink.toARGB32(), reason: file);
    }
  });

  group('appLogoOf', () {
    const package = 'com.netflix.ninja';

    test('finds_a_catalogue_app_and_a_custom_shortcut_of_the_same_package', () {
      const catalogue = AppEntry(package: package, name: 'Netflix');
      const custom = AppEntry(package: package, name: 'Films', isCustom: true);
      expect(appLogoOf(catalogue), kAppLogos[package]);
      expect(appLogoOf(custom), kAppLogos[package]);
    });

    test('gives_way_to_a_style_of_the_user', () {
      const coloured = AppEntry(
        package: package,
        name: 'Netflix',
        customColor: Color(0xFF2563EB),
      );
      const iconed = AppEntry(
        package: package,
        name: 'Netflix',
        customIcon: 'live',
      );
      expect(appLogoOf(coloured), isNull);
      expect(appLogoOf(iconed), isNull);
    });

    test('is_null_for_an_unmapped_package', () {
      expect(appLogoOf(const AppEntry(package: 'a.b', name: 'Plex')), isNull);
    });
  });
}
