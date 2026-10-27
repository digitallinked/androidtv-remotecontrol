import 'package:dynamic_color/dynamic_color.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dynamic_color_support.g.dart';

/// Whether the phone can give the app colours from its wallpaper (Android 12
/// and later with a wallpaper palette).
///
/// Settings → Appearance shows the "Colours from wallpaper" switch only when
/// this is `true`. Any error counts as "not supported".
@Riverpod(keepAlive: true)
Future<bool> dynamicColorSupported(Ref ref) async {
  try {
    return (await DynamicColorPlugin.getCorePalette()) != null;
  } on Object {
    return false;
  }
}
