import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/flavor.dart';

String read(String p) => File(p).readAsStringSync();

const _devName = 'Remotely Dev';
const _prodName = 'Remotely for Android TV';

/// Fails when [name] mentions Google, or mentions Android TV anywhere but as
/// the suffix " for Android TV".
void expectStoreSafeName(String name, {required String source}) {
  expect(
    name,
    isNot(matches(RegExp('google', caseSensitive: false))),
    reason: '$source: "$name"',
  );
  final withoutSuffix = name.endsWith(' for Android TV')
      ? name.substring(0, name.length - ' for Android TV'.length)
      : name;
  expect(
    withoutSuffix,
    isNot(matches(RegExp('android tv', caseSensitive: false))),
    reason: '$source: "$name"',
  );
}

/// The `<string>` value that follows `<key>[key]</key>` in a plist.
String plistString(String plist, String key) {
  final m = RegExp(
    '<key>$key</key>\\s*<string>([^<]*)</string>',
  ).firstMatch(plist);
  expect(m, isNotNull, reason: 'Info.plist has no $key');
  return m!.group(1)!;
}

/// The (width, height, colour type) of a PNG's IHDR chunk.
(int, int, int) pngHeader(String path) {
  final bytes = File(path).readAsBytesSync();
  expect(
    bytes.sublist(0, 8),
    [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
    reason: '$path is not a PNG',
  );
  final data = ByteData.sublistView(bytes);
  return (data.getUint32(16), data.getUint32(20), bytes[25]);
}

/// The ARGB value of the top-left pixel of the PNG at [path].
Future<int> firstPixel(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  final image = (await codec.getNextFrame()).image;
  final data = (await image.toByteData())!;
  final r = data.getUint8(0);
  final g = data.getUint8(1);
  final b = data.getUint8(2);
  final a = data.getUint8(3);
  image.dispose();
  return a << 24 | r << 16 | g << 8 | b;
}

/// The value of the `<color name="[name]">` resource in [xml], if any.
String? colorResource(String xml, String name) => RegExp(
  '<color name="$name">\\s*([^<\\s]+)\\s*</color>',
).firstMatch(xml)?.group(1);

void main() {
  test('app_names_never_mention_google', () {
    // Dart flavors.
    expect(Flavor.dev.displayName, _devName);
    expect(Flavor.prod.displayName, _prodName);
    for (final f in Flavor.values) {
      expectStoreSafeName(f.displayName, source: 'Flavor.${f.name}');
    }

    // Android labels.
    final gradle = read('android/app/build.gradle.kts');
    final gradleNames = RegExp(
      r'manifestPlaceholders\["appName"\]\s*=\s*"([^"]*)"',
    ).allMatches(gradle).map((m) => m.group(1)!).toList();
    expect(gradleNames, unorderedEquals([_devName, _prodName]));
    for (final n in gradleNames) {
      expectStoreSafeName(n, source: 'build.gradle.kts');
    }

    // iOS display names.
    final pbx = read('ios/Runner.xcodeproj/project.pbxproj');
    final iosNames = RegExp(
      'APP_DISPLAY_NAME = "([^"]*)";',
    ).allMatches(pbx).map((m) => m.group(1)!).toSet();
    expect(iosNames, {_devName, _prodName});
    for (final n in iosNames) {
      expectStoreSafeName(n, source: 'project.pbxproj');
    }

    // Info.plist strings the user can see.
    final plist = read('ios/Runner/Info.plist');
    expectStoreSafeName(
      plistString(plist, 'CFBundleName'),
      source: 'CFBundleName',
    );
    for (final key in [
      'NSLocalNetworkUsageDescription',
      'NSUserTrackingUsageDescription',
    ]) {
      expect(
        plistString(plist, key),
        isNot(matches(RegExp('google', caseSensitive: false))),
        reason: key,
      );
    }
  });

  test('branding_folder_holds_only_generated_files', () {
    final names = Directory('assets/branding')
        .listSync()
        .map((e) => e.uri.pathSegments.lastWhere((s) => s.isNotEmpty))
        .toSet();
    expect(names, {
      'icon_full.png',
      'icon_foreground.png',
      'play_store_icon_512.png',
      'splash_light.png',
      'splash_dark.png',
      'splash_android12_light.png',
      'splash_android12_dark.png',
      'brand_icon.svg',
    });
    // "android12" names the OS version whose splash API the file feeds; any
    // other mention of Google or Android in a branding file name is a mark.
    for (final n in names) {
      expect(
        n,
        isNot(matches(RegExp('google|android(?!12_)', caseSensitive: false))),
      );
    }
  });

  test('icon_and_splash_configs_use_only_our_masters', () {
    // Every `key: value` line. Whatever the key (image, image_dark, branding,
    // branding_dark, background_image, adaptive_icon_foreground, ...), a value
    // that looks like a file path must be one of our masters.
    final entry = RegExp(
      r'^[ \t]*([A-Za-z0-9_]+)[ \t]*:[ \t]*(.*?)[ \t]*(?:#.*)?$',
      multiLine: true,
    );
    final looksLikePath = RegExp(r'[/\\]|\.[A-Za-z0-9]{2,4}$');
    final paths = <String>[];
    for (final f in [
      'flutter_launcher_icons.yaml',
      'flutter_native_splash.yaml',
    ]) {
      for (final m in entry.allMatches(read(f))) {
        // Quotes are dropped; a quoted colour such as "#3D5AFE" is cut at
        // its `#` by the comment group and never looks like a path.
        final value = m.group(2)!.replaceAll(RegExp(r'''^["']|["']$'''), '');
        if (!looksLikePath.hasMatch(value)) continue;
        paths.add(value);
        expect(value, startsWith('assets/branding/'), reason: '$f ${m[1]}');
        expect(File(value).existsSync(), isTrue, reason: '$f ${m[1]}');
      }
    }
    // image_path, adaptive foreground and monochrome; the splash image and
    // image_dark, and the Android 12 image and image_dark.
    expect(paths, hasLength(7));
  });

  test('ios_marketing_icon_has_no_alpha', () {
    final (w, h, colourType) = pngHeader(
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
    );
    expect((w, h), (1024, 1024));
    expect(colourType, 2, reason: 'colour type 2 is RGB with no alpha');
  });

  test('android_adaptive_icon_has_a_monochrome_layer', () {
    final xml = read(
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
    );
    expect(xml, contains('<background'));
    expect(xml, contains('<foreground'));
    expect(xml, contains('<monochrome'));
    // The foreground master is drawn on the 108-unit adaptive canvas already;
    // an extra inset would shrink the mark below the P7-R6 geometry.
    expect(xml, isNot(contains(RegExp('android:inset="[1-9]'))));

    final (w, h, _) = pngHeader(
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
    );
    expect((w, h), (192, 192));

    final colors = read('android/app/src/main/res/values/colors.xml');
    expect(
      colorResource(colors, 'ic_launcher_background')?.toUpperCase(),
      '#3D5AFE',
    );
  });

  testWidgets('splash_background_matches_the_bg_tokens', (t) async {
    const res = 'android/app/src/main/res';
    // Android 12+: the generator writes the colour into the v31 styles.
    for (final (dir, colour) in [
      ('values-v31', '#F6F7F9'),
      ('values-night-v31', '#0F1115'),
    ]) {
      final styles = read('$res/$dir/styles.xml');
      final m = RegExp(
        r'name="android:windowSplashScreenBackground">\s*([^<\s]+)',
      ).firstMatch(styles);
      expect(m?.group(1)?.toUpperCase(), colour, reason: dir);
    }
    // Before Android 12: the launch theme draws launch_background, a layer
    // list whose base is the generator's one-colour background.png.
    for (final (night, colour) in [
      ('', 0xFFF6F7F9),
      ('-night', 0xFF0F1115),
    ]) {
      expect(
        read('$res/values$night/styles.xml'),
        contains('@drawable/launch_background'),
      );
      for (final v in ['', '-v21']) {
        expect(
          read('$res/drawable$night$v/launch_background.xml'),
          contains('@drawable/background'),
          reason: 'drawable$night$v',
        );
      }
      final pixel = await t.runAsync(
        () => firstPixel('$res/drawable$night/background.png'),
      );
      expect(pixel, colour, reason: 'drawable$night/background.png');
    }
  });
}
