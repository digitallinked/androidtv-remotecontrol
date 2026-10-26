import 'package:atv_remote/src/key_codes.dart';

/// Key names the `atv_cli key` command understands, keyed by lower-case name.
///
/// Mirrors the members of [KeyCodes]; the digits 0 to 9 are handled by
/// [parseKeyName] directly.
const Map<String, int> cliKeyCodes = {
  'dpadup': KeyCodes.dpadUp,
  'dpaddown': KeyCodes.dpadDown,
  'dpadleft': KeyCodes.dpadLeft,
  'dpadright': KeyCodes.dpadRight,
  'dpadcenter': KeyCodes.dpadCenter,
  'back': KeyCodes.back,
  'home': KeyCodes.home,
  'menu': KeyCodes.menu,
  'power': KeyCodes.power,
  'volumeup': KeyCodes.volumeUp,
  'volumedown': KeyCodes.volumeDown,
  'mute': KeyCodes.mute,
  'channelup': KeyCodes.channelUp,
  'channeldown': KeyCodes.channelDown,
  'playpause': KeyCodes.playPause,
  'next': KeyCodes.next,
  'previous': KeyCodes.previous,
  'rewind': KeyCodes.rewind,
  'fastforward': KeyCodes.fastForward,
  'stop': KeyCodes.stop,
  'red': KeyCodes.red,
  'green': KeyCodes.green,
  'yellow': KeyCodes.yellow,
  'blue': KeyCodes.blue,
  'tvinput': KeyCodes.tvInput,
  'settings': KeyCodes.settings,
  'guide': KeyCodes.guide,
  'info': KeyCodes.info,
  'captions': KeyCodes.captions,
  'search': KeyCodes.search,
  'enter': KeyCodes.enter,
  'delete': KeyCodes.delete,
};

/// Resolves a user-typed key name (case-insensitive [KeyCodes] member name, or
/// a single digit 0 to 9) to its Android key code, or `null` if unknown.
int? parseKeyName(String name) {
  final lower = name.trim().toLowerCase();
  if (RegExp(r'^[0-9]$').hasMatch(lower)) {
    return KeyCodes.digit(int.parse(lower));
  }
  return cliKeyCodes[lower];
}

/// The key names to show the user when [parseKeyName] fails.
String validKeyNames() => '${cliKeyCodes.keys.join(', ')}, 0-9';

/// Parses the `<ms>` argument of `atv_cli hold`: an integer from 1 to 30000,
/// or `null` for anything else.
int? parseHoldMillis(String raw) {
  final value = int.tryParse(raw.trim());
  if (value == null || value < 1 || value > 30000) return null;
  return value;
}
