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
  String get onboardingTryDemo => 'Try demo';

  @override
  String get demoBadgeLabel => 'Demo mode';

  @override
  String get demoLeaveAction => 'Leave';

  @override
  String get demoLeaveTitle => 'Leave demo?';

  @override
  String get demoLeaveMessage => 'You\'ll go back to the list of TVs.';

  @override
  String get demoLeaveConfirm => 'Leave demo';

  @override
  String get demoStay => 'Stay';

  @override
  String get tvPreviewTitle => 'TV preview';

  @override
  String get tvPreviewIdle => 'Press a button to see what the TV would do.';

  @override
  String tvPreviewPressed(String key) {
    return 'Pressed $key';
  }

  @override
  String tvPreviewHolding(String key) {
    return 'Holding $key';
  }

  @override
  String tvPreviewReleased(String key) {
    return 'Released $key';
  }

  @override
  String tvPreviewOpened(String link) {
    return 'Opened $link';
  }

  @override
  String tvPreviewTyped(String text) {
    return 'Typed \"$text\"';
  }

  @override
  String get tvPreviewScreenOn => 'Screen on';

  @override
  String get tvPreviewScreenOff => 'Screen off';

  @override
  String tvPreviewVolume(int level, int max) {
    return 'Volume $level of $max';
  }

  @override
  String get tvPreviewMuted => 'Muted';

  @override
  String get discoverTitle => 'Choose your TV';

  @override
  String get discoverEmptyTitle => 'No TVs found yet';

  @override
  String get discoverEmptyBody =>
      'Make sure your phone and TV are on the same Wi-Fi network and the TV is turned on.';

  @override
  String get discoverSearching => 'Looking for TVs on this Wi-Fi…';

  @override
  String get discoverScanAgain => 'Scan again';

  @override
  String get discoverEnterIp => 'Enter IP address';

  @override
  String get discoverTryDemo => 'Try demo';

  @override
  String get discoverTroubleshooting => 'Troubleshooting';

  @override
  String get discoverPaired => 'Paired';

  @override
  String get discoverUpdateNeeded => 'Update needed';

  @override
  String get discoverErrorTitle => 'Couldn\'t search for TVs';

  @override
  String get discoverErrorBody => 'Check that Wi-Fi is on, then scan again.';

  @override
  String get troubleshootTitle => 'Can\'t find your TV?';

  @override
  String get troubleshootSameWifi =>
      'Connect your phone and TV to the same Wi-Fi network (not a guest network).';

  @override
  String get troubleshootTvOn =>
      'Turn the TV on. Some TVs can\'t be found while in standby.';

  @override
  String get troubleshootRemoteService =>
      'On the TV, make sure \"Android TV Remote Service\" is installed and up to date in the Play Store.';

  @override
  String get troubleshootLocalNetwork =>
      'On iPhone, allow Local Network access for this app in Settings → Privacy & Security → Local Network.';

  @override
  String get troubleshootRestart =>
      'Still nothing? Restart the TV and your router, then scan again.';

  @override
  String get troubleshootManualIp =>
      'You can also enter the TV\'s IP address. Find it on the TV under Settings → Network & Internet.';

  @override
  String get legacyTitle => 'Update needed on this TV';

  @override
  String legacyBody(String tvName) {
    return '$tvName uses an older remote service. On the TV, open the Play Store, search for \"Android TV Remote Service\", update it, then scan again.';
  }

  @override
  String get manualIpTitle => 'Enter IP address';

  @override
  String get manualIpLabel => 'TV IP address';

  @override
  String get manualIpHint => '192.168.1.20';

  @override
  String get manualIpHelp =>
      'Find it on the TV under Settings → Network & Internet → your network.';

  @override
  String get manualIpError => 'Enter an address like 192.168.1.20';

  @override
  String get manualIpContinue => 'Continue';

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

  @override
  String get keyEnter => 'Enter';

  @override
  String get keyDelete => 'Delete';

  @override
  String get keyKeyboard => 'Keyboard';

  @override
  String pairStarting(String tvName) {
    return 'Connecting to $tvName…';
  }

  @override
  String pairEnterCode(String tvName) {
    return 'Enter the code shown on $tvName';
  }

  @override
  String get pairCodeLabel => 'Pairing code';

  @override
  String pairExpiresIn(int seconds) {
    return 'Code expires in $seconds s';
  }

  @override
  String get pairPaste => 'Paste code';

  @override
  String get pairNothingToPaste =>
      'There\'s no 6-character code on the clipboard.';

  @override
  String get pairCodeMismatch =>
      'That code doesn\'t match. Check the code on your TV and enter it again.';

  @override
  String get pairVerifying => 'Checking the code…';

  @override
  String get pairExpiredTitle => 'The code expired';

  @override
  String get pairExpiredBody =>
      'Ask the TV for a new code and enter it within 60 seconds.';

  @override
  String get pairNewCode => 'Get a new code';

  @override
  String get pairTryAgain => 'Try again';

  @override
  String get pairTroubleshooting => 'Troubleshooting';

  @override
  String pairCantReachTitle(String tvName) {
    return 'Can\'t reach $tvName';
  }

  @override
  String get pairCantReachBody =>
      'Make sure the TV is on and on the same Wi-Fi network as your phone.';

  @override
  String pairNoResponseTitle(String tvName) {
    return '$tvName didn\'t respond';
  }

  @override
  String get pairRejectedTitle => 'The TV didn\'t accept the code';

  @override
  String get pairRejectedBody =>
      'Get a new code and enter it exactly as shown.';

  @override
  String get pairErrorTitle => 'Pairing didn\'t work';

  @override
  String get pairErrorBody => 'Something unexpected happened. Try again.';

  @override
  String get pairIdentityTitle => 'Couldn\'t prepare a secure connection';

  @override
  String get pairSaveFailedTitle => 'Couldn\'t save this TV';

  @override
  String get pairNotFoundTitle => 'We couldn\'t find this TV';

  @override
  String get pairNotFoundBody =>
      'Go back to the list of TVs and choose it again.';

  @override
  String get remotePadTabsLabel => 'Control style';

  @override
  String get remotePadTouchpad => 'Touchpad';

  @override
  String get remotePadDpad => 'D-pad';

  @override
  String get remotePadNumbers => 'Numbers';

  @override
  String get touchpadLabel => 'Touchpad';

  @override
  String get touchpadHint =>
      'Swipe to move, tap to select, tap with two fingers to go back.';

  @override
  String get touchpadIdleHint => 'Swipe to move · Tap to select';

  @override
  String get channelLabel => 'CH';

  @override
  String remoteVolumeValue(int level) {
    return '$level';
  }

  @override
  String get remoteMutedValue => 'Muted';

  @override
  String remoteVolumeSemantics(int level, int max) {
    return 'Volume $level of $max';
  }

  @override
  String get remoteVolumeMutedSemantics => 'Volume muted';

  @override
  String get quickAccessAppsLabel => 'Apps on your TV';

  @override
  String get quickAccessColourLabel => 'Colour keys';

  @override
  String get quickAccessMediaLabel => 'Media keys';

  @override
  String quickAppOpen(String app) {
    return 'Open $app';
  }

  @override
  String quickAppNowOnTv(String app) {
    return '$app, now on TV';
  }

  @override
  String get powerHoldHint => 'Hold to turn the TV on or off';

  @override
  String powerWaking(String tvName) {
    return 'Waking $tvName…';
  }

  @override
  String get powerWakeFailed =>
      'Couldn\'t send the wake-up signal. Make sure your phone is on the same Wi-Fi as the TV.';

  @override
  String get powerTurnOnWithTvRemote =>
      'Turn the TV on with its own remote. This app reconnects by itself.';

  @override
  String wolSetupTitle(String tvName) {
    return 'Turn on $tvName from your phone';
  }

  @override
  String get wolSetupBody =>
      'Your phone can wake the TV over the network with its MAC address. On the TV, open Settings → System → About → Status (or Settings → Network & Internet) and copy the Wi-Fi or Ethernet MAC address.';

  @override
  String get wolNotBluetooth =>
      'Use the Wi-Fi or Ethernet MAC address, not the Bluetooth one.';

  @override
  String get wolMayNotWork =>
      'Some TVs can\'t be woken when they\'re fully off or in deep standby.';

  @override
  String get wolMacLabel => 'MAC address';

  @override
  String get wolMacHint => 'AA:BB:CC:DD:EE:FF';

  @override
  String get wolMacError =>
      'Enter 6 pairs of letters or digits, like AA:BB:CC:DD:EE:FF';

  @override
  String get wolSaveAndWake => 'Save and turn on';

  @override
  String get wolSaveFailed => 'Couldn\'t save the MAC address. Try again.';

  @override
  String get keyboardTitle => 'Type on your TV';

  @override
  String get keyboardFieldLabel => 'Text';

  @override
  String get keyboardHint => 'Start typing…';

  @override
  String get keyboardTvHint =>
      'Select a text field on the TV first, like the search box.';

  @override
  String get keyboardClear => 'Clear';

  @override
  String get keyboardOpenTvSearch => 'Open search on TV';

  @override
  String get keyboardNotConnected =>
      'Not connected to your TV. What you type isn\'t sent.';

  @override
  String get theaterWakeLabel => 'Screen dimmed. Touch to brighten.';
}
