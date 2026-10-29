import 'package:atv_remote/atv_remote.dart';

/// The names a `key_press` event may carry (Ruling P6-R6): every key the
/// remote sends, `digit` for all ten digit keys and `other` for the rest.
const Set<String> analyticsKeyNames = {
  'dpad_up',
  'dpad_down',
  'dpad_left',
  'dpad_right',
  'dpad_center',
  'back',
  'home',
  'menu',
  'power',
  'volume_up',
  'volume_down',
  'mute',
  'channel_up',
  'channel_down',
  'play_pause',
  'next',
  'previous',
  'rewind',
  'fast_forward',
  'stop',
  'red',
  'green',
  'yellow',
  'blue',
  'tv_input',
  'settings',
  'guide',
  'info',
  'captions',
  'search',
  'enter',
  'delete',
  'digit',
  'other',
};

const Map<int, String> _names = {
  KeyCodes.dpadUp: 'dpad_up',
  KeyCodes.dpadDown: 'dpad_down',
  KeyCodes.dpadLeft: 'dpad_left',
  KeyCodes.dpadRight: 'dpad_right',
  KeyCodes.dpadCenter: 'dpad_center',
  KeyCodes.back: 'back',
  KeyCodes.home: 'home',
  KeyCodes.menu: 'menu',
  KeyCodes.power: 'power',
  KeyCodes.volumeUp: 'volume_up',
  KeyCodes.volumeDown: 'volume_down',
  KeyCodes.mute: 'mute',
  KeyCodes.channelUp: 'channel_up',
  KeyCodes.channelDown: 'channel_down',
  KeyCodes.playPause: 'play_pause',
  KeyCodes.next: 'next',
  KeyCodes.previous: 'previous',
  KeyCodes.rewind: 'rewind',
  KeyCodes.fastForward: 'fast_forward',
  KeyCodes.stop: 'stop',
  KeyCodes.red: 'red',
  KeyCodes.green: 'green',
  KeyCodes.yellow: 'yellow',
  KeyCodes.blue: 'blue',
  KeyCodes.tvInput: 'tv_input',
  KeyCodes.settings: 'settings',
  KeyCodes.guide: 'guide',
  KeyCodes.info: 'info',
  KeyCodes.captions: 'captions',
  KeyCodes.search: 'search',
  KeyCodes.enter: 'enter',
  KeyCodes.delete: 'delete',
};

/// The analytics name of [keyCode]. Digits are all `digit`: which digit was
/// pressed could be part of a PIN, so it is never logged.
String analyticsKeyName(int keyCode) {
  final named = _names[keyCode];
  if (named != null) return named;
  for (var n = 0; n <= 9; n++) {
    if (keyCode == KeyCodes.digit(n)) return 'digit';
  }
  return 'other';
}
