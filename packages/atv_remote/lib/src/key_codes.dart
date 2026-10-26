import 'package:atv_remote/src/proto/remotemessage.pbenum.dart';

/// Android `KeyEvent` key codes the remote UI sends to the TV.
///
/// Values follow android.view.KeyEvent and `protocol-reference.md`. Any other
/// code in the generated `RemoteKeyCode` enum can still be passed to
/// `RemoteClient.sendKey` as a plain int.
abstract final class KeyCodes {
  /// DPAD_UP.
  static const int dpadUp = 19;

  /// DPAD_DOWN.
  static const int dpadDown = 20;

  /// DPAD_LEFT.
  static const int dpadLeft = 21;

  /// DPAD_RIGHT.
  static const int dpadRight = 22;

  /// DPAD_CENTER (select / OK).
  static const int dpadCenter = 23;

  /// BACK.
  static const int back = 4;

  /// HOME.
  static const int home = 3;

  /// MENU.
  static const int menu = 82;

  /// POWER.
  static const int power = 26;

  /// VOLUME_UP.
  static const int volumeUp = 24;

  /// VOLUME_DOWN.
  static const int volumeDown = 25;

  /// VOLUME_MUTE.
  static const int mute = 164;

  /// CHANNEL_UP.
  static const int channelUp = 166;

  /// CHANNEL_DOWN.
  static const int channelDown = 167;

  /// MEDIA_PLAY_PAUSE.
  static const int playPause = 85;

  /// MEDIA_NEXT.
  static const int next = 87;

  /// MEDIA_PREVIOUS.
  static const int previous = 88;

  /// MEDIA_REWIND.
  static const int rewind = 89;

  /// MEDIA_FAST_FORWARD.
  static const int fastForward = 90;

  /// MEDIA_STOP.
  static const int stop = 86;

  /// PROG_RED.
  static const int red = 183;

  /// PROG_GREEN.
  static const int green = 184;

  /// PROG_YELLOW.
  static const int yellow = 185;

  /// PROG_BLUE.
  static const int blue = 186;

  /// TV_INPUT.
  static const int tvInput = 178;

  /// SETTINGS.
  static const int settings = 176;

  /// GUIDE.
  static const int guide = 172;

  /// INFO.
  static const int info = 165;

  /// CAPTIONS.
  static const int captions = 175;

  /// SEARCH.
  static const int search = 84;

  /// ENTER (confirms text entry).
  static const int enter = 66;

  /// DEL (`KEYCODE_DEL`): deletes the character before the cursor, like a
  /// keyboard's backspace.
  static const int delete = 67;

  /// Every named constant above (not the digits), in declaration order.
  static const List<int> named = [
    dpadUp,
    dpadDown,
    dpadLeft,
    dpadRight,
    dpadCenter,
    back,
    home,
    menu,
    power,
    volumeUp,
    volumeDown,
    mute,
    channelUp,
    channelDown,
    playPause,
    next,
    previous,
    rewind,
    fastForward,
    stop,
    red,
    green,
    yellow,
    blue,
    tvInput,
    settings,
    guide,
    info,
    captions,
    search,
    enter,
    delete,
  ];

  /// The key code of the digit key [n], from 0 to 9 (KEYCODE_0 is 7).
  ///
  /// Throws a [RangeError] for any other value.
  static int digit(int n) {
    RangeError.checkValueInInterval(n, 0, 9, 'n');
    return 7 + n;
  }
}

/// How a key press is delivered to the TV.
enum KeyDirection {
  /// A normal tap (press and release).
  short,

  /// The key goes down and stays down: start of a press-and-hold.
  startLong,

  /// The key is released after a [startLong].
  endLong,
}

/// Whether the protocol has a name for [keyCode], so `RemoteClient.sendKey`
/// accepts it. True for every [KeyCodes] constant and digit.
bool isSupportedKeyCode(int keyCode) => RemoteKeyCode.valueOf(keyCode) != null;
