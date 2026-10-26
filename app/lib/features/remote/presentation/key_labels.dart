import 'package:atv_remote/atv_remote.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';

/// The spoken label of the remote key [keyCode] (an Android `KeyEvent` code).
///
/// Every `KeyCodes` constant has a specific label, the digits 0 to 9 are
/// "Number n", and any other code is "Key n".
String keyLabel(AppLocalizations l10n, int keyCode) {
  final first = KeyCodes.digit(0);
  if (keyCode >= first && keyCode <= KeyCodes.digit(9)) {
    return l10n.keyNumber(keyCode - first);
  }
  return switch (keyCode) {
    KeyCodes.dpadUp => l10n.keyUp,
    KeyCodes.dpadDown => l10n.keyDown,
    KeyCodes.dpadLeft => l10n.keyLeft,
    KeyCodes.dpadRight => l10n.keyRight,
    KeyCodes.dpadCenter => l10n.keyOk,
    KeyCodes.back => l10n.keyBack,
    KeyCodes.home => l10n.keyHome,
    KeyCodes.menu => l10n.keyMenu,
    KeyCodes.power => l10n.keyPower,
    KeyCodes.volumeUp => l10n.keyVolumeUp,
    KeyCodes.volumeDown => l10n.keyVolumeDown,
    KeyCodes.mute => l10n.keyMute,
    KeyCodes.channelUp => l10n.keyChannelUp,
    KeyCodes.channelDown => l10n.keyChannelDown,
    KeyCodes.playPause => l10n.keyPlayPause,
    KeyCodes.next => l10n.keyNext,
    KeyCodes.previous => l10n.keyPrevious,
    KeyCodes.rewind => l10n.keyRewind,
    KeyCodes.fastForward => l10n.keyFastForward,
    KeyCodes.stop => l10n.keyStop,
    KeyCodes.red => l10n.keyRed,
    KeyCodes.green => l10n.keyGreen,
    KeyCodes.yellow => l10n.keyYellow,
    KeyCodes.blue => l10n.keyBlue,
    KeyCodes.tvInput => l10n.keyTvInput,
    KeyCodes.settings => l10n.keySettings,
    KeyCodes.guide => l10n.keyGuide,
    KeyCodes.info => l10n.keyInfo,
    KeyCodes.captions => l10n.keyCaptions,
    KeyCodes.search => l10n.keySearch,
    KeyCodes.enter => l10n.keyEnter,
    KeyCodes.delete => l10n.keyDelete,
    _ => l10n.keyUnknown(keyCode),
  };
}
