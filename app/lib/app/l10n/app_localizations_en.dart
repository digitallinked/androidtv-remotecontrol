// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get statusConnected => 'Connected';

  @override
  String get statusConnecting => 'Connecting…';

  @override
  String get statusReconnecting => 'Reconnecting…';

  @override
  String get statusOffline => 'Offline';

  @override
  String get statusNeedsPairing => 'Needs pairing';

  @override
  String get statusDisconnected => 'Not connected';

  @override
  String get statusReconnectAction => 'Reconnect';

  @override
  String statusSemantics(String status) {
    return 'Connection: $status';
  }

  @override
  String get closeAction => 'Close';

  @override
  String get onboardingTitle => 'Control your TV from your phone';

  @override
  String get onboardingBody =>
      'Find your Android TV on this Wi-Fi network and pair it in a few seconds.';

  @override
  String get onboardingGetStarted => 'Get started';

  @override
  String get discoverTitle => 'Choose your TV';

  @override
  String get discoverEmptyTitle => 'No TVs found yet';

  @override
  String get discoverEmptyBody =>
      'Make sure your phone and TV are on the same Wi-Fi network and the TV is turned on.';

  @override
  String get pageTitlePair => 'Pair your TV';

  @override
  String get pageTitleRemote => 'Remote';

  @override
  String get pageTitleApps => 'Apps';

  @override
  String get pageTitleDevices => 'Devices';

  @override
  String get pageTitleSettings => 'Settings';

  @override
  String get pageTitlePaywall => 'Premium';

  @override
  String get placeholderBody => 'This screen is coming soon.';

  @override
  String get routeNotFoundTitle => 'Page not found';

  @override
  String get routeNotFoundBody => 'We couldn\'t find that page.';

  @override
  String get routeNotFoundAction => 'Back to TVs';

  @override
  String get statusPairAgainAction => 'Pair again';

  @override
  String get remoteNotConnected => 'Not connected to your TV';

  @override
  String get remoteSwitchTv => 'Switch TV';

  @override
  String get remoteAddTv => 'Add a TV';

  @override
  String get remoteNoTvTitle => 'No TV selected';

  @override
  String get remoteNoTvAction => 'Choose a TV';

  @override
  String get remoteIdentityChangedTitle => 'This TV\'s identity changed';

  @override
  String remoteIdentityChangedMessage(String tvName) {
    return '$tvName presented a different security key than when you paired it. If the TV was reset or replaced, pair it again.';
  }

  @override
  String get remoteNotNow => 'Not now';

  @override
  String get remoteSessionErrorTitle => 'Couldn\'t prepare a secure connection';

  @override
  String get remoteSessionErrorBody =>
      'Something went wrong while loading this phone\'s security key.';

  @override
  String get remoteRetry => 'Try again';

  @override
  String get demoTvName => 'Demo TV';

  @override
  String get volumeLabel => 'VOL';

  @override
  String keyNumber(int digit) {
    return 'Number $digit';
  }

  @override
  String keyUnknown(int code) {
    return 'Key $code';
  }

  @override
  String get keyUp => 'Up';

  @override
  String get keyDown => 'Down';

  @override
  String get keyLeft => 'Left';

  @override
  String get keyRight => 'Right';

  @override
  String get keyOk => 'OK';

  @override
  String get keyBack => 'Back';

  @override
  String get keyHome => 'Home';

  @override
  String get keyMenu => 'Menu';

  @override
  String get keyPower => 'Power';

  @override
  String get keyVolumeUp => 'Volume up';

  @override
  String get keyVolumeDown => 'Volume down';

  @override
  String get keyMute => 'Mute';

  @override
  String get keyChannelUp => 'Channel up';

  @override
  String get keyChannelDown => 'Channel down';

  @override
  String get keyPlayPause => 'Play or pause';

  @override
  String get keyNext => 'Next';

  @override
  String get keyPrevious => 'Previous';

  @override
  String get keyRewind => 'Rewind';

  @override
  String get keyFastForward => 'Fast forward';

  @override
  String get keyStop => 'Stop';

  @override
  String get keyRed => 'Red';

  @override
  String get keyGreen => 'Green';

  @override
  String get keyYellow => 'Yellow';

  @override
  String get keyBlue => 'Blue';

  @override
  String get keyTvInput => 'TV input';

  @override
  String get keySettings => 'Settings';

  @override
  String get keyGuide => 'Guide';

  @override
  String get keyInfo => 'Info';

  @override
  String get keyCaptions => 'Captions';

  @override
  String get keySearch => 'Search';
}
