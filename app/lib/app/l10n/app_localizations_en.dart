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
  String get pageTitleDevices => 'Your TVs';

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

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonUndo => 'Undo';

  @override
  String get commonRetry => 'Try again';

  @override
  String get remoteManageTvs => 'Manage TVs';

  @override
  String get quickAccessAllApps => 'All apps';

  @override
  String get pageTitleManageApps => 'Edit apps';

  @override
  String get pageTitleEditDevice => 'Edit TV';

  @override
  String get pageTitleAppearance => 'Appearance';

  @override
  String get pageTitleRemoteLayout => 'Remote layout';

  @override
  String get pageTitleRemoteBehaviour => 'Remote behaviour';

  @override
  String get pageTitleHelp => 'Help';

  @override
  String get pageTitleAbout => 'About this app';

  @override
  String get appsSearchLabel => 'Search apps';

  @override
  String get appsYourApps => 'Your apps';

  @override
  String get appsMoreApps => 'More apps';

  @override
  String appsNoMatches(String query) {
    return 'No apps match \"$query\".';
  }

  @override
  String get appsEmptyTitle => 'No apps yet';

  @override
  String get appsLoadFailed => 'Couldn\'t load your apps.';

  @override
  String get appsEmptyBody =>
      'Add the apps you use on your TV to open them with one tap.';

  @override
  String get appsEmptyAction => 'Add apps';

  @override
  String get manageAppsAdd => 'Add app';

  @override
  String get manageAppsReset => 'Reset to suggested apps';

  @override
  String get manageAppsResetTitle => 'Reset your apps?';

  @override
  String get manageAppsResetBody =>
      'Your list goes back to the suggested apps for your region. Shortcuts you added or changed are removed.';

  @override
  String get manageAppsResetConfirm => 'Reset';

  @override
  String get manageAppsReorderHint =>
      'Drag the handle to change the order. The remote shows your apps in this order.';

  @override
  String manageAppsDragHandle(String app) {
    return 'Reorder $app';
  }

  @override
  String manageAppsEdit(String app) {
    return 'Edit $app';
  }

  @override
  String manageAppsRemove(String app) {
    return 'Remove $app';
  }

  @override
  String manageAppsRemoved(String app) {
    return '$app removed';
  }

  @override
  String get manageAppsEmpty =>
      'No apps on your list. Add one to see it on the remote.';

  @override
  String get manageAppsSaveFailed => 'Couldn\'t save your apps. Try again.';

  @override
  String get addAppTitle => 'Add an app';

  @override
  String get addAppSearchLabel => 'Search apps or enter an app ID';

  @override
  String get addAppCustom => 'Create a custom shortcut';

  @override
  String get addAppRecentTitle => 'Recently used on your TV';

  @override
  String get addAppRecentEmpty => 'Apps you open on your TV show up here.';

  @override
  String get addAppPopularTitle => 'Suggested apps';

  @override
  String get addAppNoResults =>
      'No apps found. If you know the app\'s ID, type it to add it.';

  @override
  String addAppById(String package) {
    return 'Add app ID \"$package\"';
  }

  @override
  String addAppAdded(String app) {
    return '$app added';
  }

  @override
  String get addAppAlreadyAdded => 'Already on your list';

  @override
  String get shortcutNewTitle => 'New shortcut';

  @override
  String get shortcutEditTitle => 'Edit shortcut';

  @override
  String get shortcutNameLabel => 'Name';

  @override
  String get shortcutNameError => 'Enter a name of up to 30 characters.';

  @override
  String get shortcutPackageLabel => 'App ID';

  @override
  String get shortcutPackageHint => 'com.example.app';

  @override
  String get shortcutPackageHelp =>
      'The app\'s ID on the TV. It\'s in the app\'s Play Store web address, after \"id=\".';

  @override
  String get shortcutPackageError => 'Enter an app ID like com.example.app.';

  @override
  String get shortcutPackageTaken => 'This app is already on your list.';

  @override
  String get shortcutColourLabel => 'Tile colour';

  @override
  String get shortcutColourDefault => 'Default';

  @override
  String get shortcutColourSlate => 'Slate';

  @override
  String get shortcutColourBlue => 'Blue';

  @override
  String get shortcutColourTeal => 'Teal';

  @override
  String get shortcutColourGreen => 'Green';

  @override
  String get shortcutColourAmber => 'Amber';

  @override
  String get shortcutColourOrange => 'Orange';

  @override
  String get shortcutColourRed => 'Red';

  @override
  String get shortcutColourPurple => 'Purple';

  @override
  String get shortcutIconLabel => 'Icon';

  @override
  String get shortcutIconLetter => 'First letter';

  @override
  String get shortcutIconApp => 'App';

  @override
  String get shortcutIconMovies => 'Movies';

  @override
  String get shortcutIconLive => 'Live TV';

  @override
  String get shortcutIconSports => 'Sports';

  @override
  String get shortcutIconMusic => 'Music';

  @override
  String get shortcutIconKids => 'Kids';

  @override
  String get shortcutIconNews => 'News';

  @override
  String get shortcutIconGames => 'Games';

  @override
  String get shortcutIconLearning => 'Learning';

  @override
  String get shortcutPreview => 'Preview';

  @override
  String get shortcutSaved => 'Shortcut saved';

  @override
  String get devicesEmptyTitle => 'No TVs yet';

  @override
  String get devicesLoadFailed => 'Couldn\'t load your TVs.';

  @override
  String get devicesEmptyBody => 'Pair a TV to control it from this phone.';

  @override
  String get devicesInUse => 'In use';

  @override
  String devicesEditTv(String tvName) {
    return 'Edit $tvName';
  }

  @override
  String get editDeviceNameLabel => 'Name on this phone';

  @override
  String editDeviceNameHelp(String tvName) {
    return 'Leave empty to use the TV\'s own name, $tvName.';
  }

  @override
  String get editDeviceNameError => 'Use 40 characters or fewer.';

  @override
  String get editDeviceWolTitle => 'Turn on from your phone';

  @override
  String get editDeviceWolBody =>
      'Add the TV\'s MAC address so the power key can wake it from standby.';

  @override
  String get editDeviceWolHelp => 'Where do I find it?';

  @override
  String get editDeviceWolUnavailable =>
      'Turning the TV on from an iPhone isn\'t available yet. You can still save the address.';

  @override
  String get wolMacTooLong =>
      'That\'s longer than a MAC address. Check what you pasted.';

  @override
  String get wolHelpTitle => 'Find the TV\'s MAC address';

  @override
  String editDeviceLastAddress(String host) {
    return 'Last address: $host';
  }

  @override
  String get editDeviceSaved => 'Saved';

  @override
  String get editDeviceSaveFailed => 'Couldn\'t save. Try again.';

  @override
  String get editDeviceRemove => 'Remove TV';

  @override
  String get editDeviceRemoveFailed => 'Couldn\'t remove this TV. Try again.';

  @override
  String editDeviceRemoveTitle(String tvName) {
    return 'Remove $tvName?';
  }

  @override
  String get editDeviceRemoveBody =>
      'This phone forgets the TV and its settings. To use it again, pair it with a new code. The TV may still list this phone.';

  @override
  String get editDeviceRemoveConfirm => 'Remove';

  @override
  String editDeviceRemoved(String tvName) {
    return '$tvName removed';
  }

  @override
  String get editDeviceNotFound =>
      'This TV isn\'t saved on this phone anymore.';

  @override
  String get editDeviceBackToTvs => 'Back to your TVs';

  @override
  String get discoverOpenFailed => 'Couldn\'t open this TV. Try again.';

  @override
  String get settingsSectionRemote => 'Remote';

  @override
  String get settingsSectionApp => 'App';

  @override
  String get settingsSectionSupport => 'Help and feedback';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsRemoteLayoutSubtitle =>
      'Touchpad or D-pad, and the row of keys above it';

  @override
  String get settingsRemoteBehaviourSubtitle =>
      'Vibration, Smooth Press, screen and keyboard';

  @override
  String get settingsAppsSubtitle => 'Choose and order your app shortcuts';

  @override
  String get settingsDevicesSubtitle =>
      'Rename, remove, or turn on from your phone';

  @override
  String get settingsAppearanceSubtitle => 'Theme and language';

  @override
  String get settingsHelpSubtitle => 'Common questions and troubleshooting';

  @override
  String get settingsFeedback => 'Send feedback';

  @override
  String get settingsFeedbackSubtitle => 'Write to us by email';

  @override
  String get settingsAboutSubtitle => 'Version and licences';

  @override
  String get settingsPrivacy => 'Privacy policy';

  @override
  String get settingsTerms => 'Terms of use';

  @override
  String get settingsOpensInBrowser => 'Opens in your browser';

  @override
  String get settingsLinkFailed =>
      'Couldn\'t open the page. Check your internet connection and try again.';

  @override
  String get appearanceTheme => 'Theme';

  @override
  String get appearanceThemeSystem => 'Same as phone';

  @override
  String get appearanceThemeLight => 'Light';

  @override
  String get appearanceThemeDark => 'Dark';

  @override
  String get appearanceDynamicColour => 'Colours from wallpaper';

  @override
  String get appearanceDynamicColourSubtitle =>
      'Use your phone\'s wallpaper colours in the app.';

  @override
  String get appearanceLanguage => 'Language';

  @override
  String get appearanceLanguageSystem => 'Same as phone';

  @override
  String get layoutPreviewTitle => 'Preview';

  @override
  String get layoutPreviewSemantics =>
      'Preview of the remote with these choices';

  @override
  String get layoutNavigation => 'Navigation';

  @override
  String get layoutTouchpadSubtitle => 'Swipe to move, tap to select.';

  @override
  String get layoutDpadSubtitle =>
      'Arrow keys around an OK button, like a TV remote.';

  @override
  String get layoutQuickAccess => 'Row above the pad';

  @override
  String get layoutQuickApps => 'App shortcuts';

  @override
  String get layoutQuickAppsSubtitle => 'Open your TV apps with one tap.';

  @override
  String get layoutQuickColourSubtitle => 'Red, green, yellow and blue keys.';

  @override
  String get layoutQuickMediaSubtitle =>
      'Previous, rewind, play or pause, fast-forward and next.';

  @override
  String get layoutQuickNone => 'Nothing';

  @override
  String get layoutQuickNoneSubtitle => 'More room for the touchpad or D-pad.';

  @override
  String get behaviourHaptics => 'Vibrate on key press';

  @override
  String get behaviourHapticsSubtitle =>
      'A short vibration when a key reaches the TV.';

  @override
  String get behaviourSmoothPress => 'Smooth Press';

  @override
  String get behaviourSmoothPressSubtitle =>
      'Holding volume, channel or arrow keys acts like holding a key on a TV remote. When off, holding repeats the key.';

  @override
  String get behaviourKeepAwake => 'Keep screen on';

  @override
  String get behaviourKeepAwakeSubtitle =>
      'Your phone\'s screen stays on while the remote is open.';

  @override
  String get behaviourTheater => 'Theater mode';

  @override
  String get behaviourTheaterSubtitle =>
      'Dims your phone after 30 seconds without a touch. The first touch only brightens it.';

  @override
  String get behaviourAutoKeyboard => 'Open keyboard automatically';

  @override
  String get behaviourAutoKeyboardSubtitle =>
      'Opens the keyboard when the TV asks for text, like in a search box.';

  @override
  String get helpCantConnectTitle => 'Can\'t connect?';

  @override
  String get helpCantConnectBody =>
      'Go through the checks one at a time. Most problems come from the Wi-Fi network or the TV\'s remote service.';

  @override
  String get helpTroubleshootingAction => 'Show troubleshooting steps';

  @override
  String get helpFaqTitle => 'Common questions';

  @override
  String get helpStillStuck => 'Still stuck?';

  @override
  String get faqTvsQ => 'Which TVs does this app work with?';

  @override
  String get faqTvsA =>
      'TVs and streaming boxes that run Android TV or Google TV, on the same Wi-Fi network as your phone. TVs with other systems, such as Samsung (Tizen), LG (webOS), Roku or Fire TV, can\'t be controlled by this app.';

  @override
  String get faqNotFoundQ => 'My TV isn\'t in the list.';

  @override
  String get faqNotFoundA =>
      'Make sure the TV is on and connected to the same Wi-Fi as your phone, and that \"Android TV Remote Service\" is up to date on the TV. You can also add the TV by its IP address. The troubleshooting steps go through each check.';

  @override
  String get faqCodeQ => 'Why does the TV ask for a code again?';

  @override
  String get faqCodeA =>
      'Pairing makes the TV and this phone trust each other. Clearing the app\'s data, reinstalling the app or resetting the TV removes that trust, so you pair once more with a new code.';

  @override
  String get faqPowerQ => 'Why can\'t the app turn my TV on?';

  @override
  String get faqPowerA =>
      'A TV that is fully off can\'t hear the app. The app can send a wake-up signal if you add the TV\'s MAC address under Settings → Your TVs, but some TVs ignore it in deep standby. On iPhone this isn\'t available yet.';

  @override
  String get faqTypingQ => 'What I type doesn\'t show up on the TV.';

  @override
  String get faqTypingA =>
      'Select a text field on the TV first, such as a search box. When the TV asks for text, the keyboard opens on your phone by itself.';

  @override
  String get faqAppQ => 'An app shortcut doesn\'t open.';

  @override
  String get faqAppA =>
      'The app has to be installed on the TV. Some apps have a different version in each country: add the right one by its app ID under Settings → Apps.';

  @override
  String get faqPrivacyQ => 'What does the app keep about my TV?';

  @override
  String get faqPrivacyA =>
      'Your TV\'s name, network address and MAC address stay on this phone. The app can send anonymous usage statistics and crash reports, which never include them. You can turn each on or off in Settings → Privacy choices.';

  @override
  String aboutVersion(String version, String build) {
    return 'Version $version ($build)';
  }

  @override
  String get aboutVersionUnknown => 'Version unavailable';

  @override
  String get aboutLicences => 'Open-source licences';

  @override
  String get aboutProtocol =>
      'Talks to your TV over Wi-Fi with the Android TV Remote protocol. Its message formats come from the open-source androidtvremote2 project.';

  @override
  String get aboutTrademark =>
      'Android TV and Google TV are trademarks of Google LLC. This app isn\'t made or endorsed by Google.';

  @override
  String get feedbackTitle => 'Send feedback?';

  @override
  String get feedbackBody =>
      'Your email app opens with a message to us. It includes the app version and your phone\'s system version, and nothing about your TV.';

  @override
  String get feedbackConfirm => 'Write email';

  @override
  String feedbackSubject(String appName, String version) {
    return 'Feedback on $appName $version';
  }

  @override
  String get feedbackPrompt => 'Write your message here.';

  @override
  String feedbackNoEmailApp(String email) {
    return 'No email app found. Write to us at $email.';
  }

  @override
  String get settingsPremiumSubtitle => 'No ads and extra colour styles';

  @override
  String get settingsPremiumActiveSubtitle => 'You have Premium. Thank you!';

  @override
  String get pageTitlePrivacyChoices => 'Privacy choices';

  @override
  String get settingsPrivacyChoicesSubtitle =>
      'Usage statistics, crash reports and ads';

  @override
  String get aboutTestCrash => 'Send a test crash report';

  @override
  String get aboutTestCrashSent =>
      'Test crash report sent. It shows in Crashlytics within a few minutes.';

  @override
  String get privacyIntro =>
      'Choose what the app may share. Your TV\'s name, network address and MAC address never leave this phone.';

  @override
  String get privacySectionImprove => 'Help improve the app';

  @override
  String get privacyUsageTitle => 'Share usage statistics';

  @override
  String get privacyUsageSubtitle =>
      'Anonymous counts of the screens and features you use. Never what you type or anything about your TV.';

  @override
  String get privacyCrashTitle => 'Share crash reports';

  @override
  String get privacyCrashSubtitle =>
      'Sent when something goes wrong, so it can be fixed. Names, addresses and codes are removed first.';

  @override
  String get privacyServicesOff =>
      'This build of the app doesn\'t send usage statistics or crash reports.';

  @override
  String get privacySectionAds => 'Ads';

  @override
  String get privacyAdsInfo =>
      'The free app shows a banner ad at the bottom of the Apps and Settings screens only.';

  @override
  String get privacyAdsPremium => 'You have Premium, so the app shows no ads.';

  @override
  String get privacyAdChoices => 'Ad privacy choices';

  @override
  String get privacyAdChoicesSubtitle => 'Choose how ads are picked for you.';

  @override
  String get privacyAdChoicesFailed =>
      'Couldn\'t open ad privacy choices. Check your internet connection and try again.';

  @override
  String get privacyRemoveAds => 'Remove ads with Premium';

  @override
  String get privacyTrackingTitle => 'Ad tracking';

  @override
  String get privacyTrackingAllowed =>
      'Allowed. You can change this in your iPhone\'s Settings.';

  @override
  String get privacyTrackingDenied =>
      'Not allowed. You can change this in your iPhone\'s Settings.';

  @override
  String get privacyTrackingNotDetermined =>
      'Not chosen yet. The app asks before it first shows an ad.';

  @override
  String get privacyTrackingRestricted => 'Turned off on this iPhone.';

  @override
  String get privacyOpensSettings => 'Opens your phone\'s Settings';

  @override
  String get trackingPrepromptTitle => 'About ads in this app';

  @override
  String get trackingPrepromptBody =>
      'The free app shows a small ad at the bottom of this screen. Next, your iPhone asks whether the app may use your activity in other apps to choose ads. You see the same number of ads whatever you choose, and the remote works the same.';

  @override
  String get trackingPrepromptContinue => 'Continue';

  @override
  String get adLabel => 'Advertisement';

  @override
  String get paywallHeadline => 'Make the remote yours';

  @override
  String get paywallSubhead =>
      'Premium removes ads, adds colour styles and supports the app\'s development.';

  @override
  String get paywallBenefitNoAds => 'No ads';

  @override
  String get paywallBenefitNoAdsBody =>
      'No banner on the Apps and Settings screens.';

  @override
  String get paywallBenefitStyles => 'Colour styles';

  @override
  String get paywallBenefitStylesBody =>
      'Ocean, Ember and Midnight, in light and dark.';

  @override
  String get paywallFreeForever =>
      'Everything else stays free: every TV, every remote control, app shortcuts, the keyboard and turning your TV on.';

  @override
  String get paywallChoosePlan => 'Choose a plan';

  @override
  String get paywallPlanMonthly => 'Monthly';

  @override
  String get paywallPlanYearly => 'Yearly';

  @override
  String get paywallPlanLifetime => 'Lifetime';

  @override
  String paywallPricePerMonth(String price) {
    return '$price per month';
  }

  @override
  String paywallPricePerYear(String price) {
    return '$price per year';
  }

  @override
  String paywallPriceOnce(String price) {
    return '$price, one payment';
  }

  @override
  String get paywallRenewsMonthly => 'Renews every month until you cancel.';

  @override
  String get paywallRenewsYearly => 'Renews every year until you cancel.';

  @override
  String get paywallLifetimeTerms => 'Pay once. No subscription.';

  @override
  String get paywallBestValue => 'Best value';

  @override
  String paywallSavePercent(int percent) {
    return 'Save $percent%';
  }

  @override
  String get paywallContinue => 'Continue';

  @override
  String get paywallRestore => 'Restore purchases';

  @override
  String get paywallTermsAndroid =>
      'Payment is charged to your Google Play account. Subscriptions renew automatically until you cancel them in Google Play, and you keep Premium until the end of the period you paid for.';

  @override
  String get paywallTermsIos =>
      'Payment is charged to your Apple ID. Subscriptions renew automatically unless you cancel at least 24 hours before the end of the current period. Manage or cancel them in your Apple ID settings.';

  @override
  String get paywallLoading => 'Loading plans…';

  @override
  String get paywallUnavailableTitle => 'Premium isn\'t available right now';

  @override
  String get paywallUnavailableBody =>
      'Check your internet connection and try again.';

  @override
  String get paywallPurchasing => 'Confirming your purchase…';

  @override
  String get paywallWelcome => 'Welcome to Premium. Thank you!';

  @override
  String get paywallPending =>
      'Your purchase is waiting for approval. Premium starts as soon as it\'s complete.';

  @override
  String get paywallFailed => 'The purchase didn\'t go through. Try again.';

  @override
  String get paywallNetworkError =>
      'Couldn\'t reach the store. Check your internet connection and try again.';

  @override
  String get paywallNotAllowed => 'Purchases aren\'t allowed on this phone.';

  @override
  String get paywallAlreadyOwned =>
      'You already own Premium. Tap Restore purchases to get it back.';

  @override
  String get paywallRestored => 'Purchases restored. You have Premium.';

  @override
  String get paywallNothingToRestore => 'No purchases found for this account.';

  @override
  String get paywallRestoreFailed => 'Couldn\'t restore purchases. Try again.';

  @override
  String get paywallActiveTitle => 'You have Premium';

  @override
  String get paywallActiveBody =>
      'Thank you for supporting the app. There are no ads, and every colour style is yours.';

  @override
  String get paywallActiveLifetime => 'Lifetime Premium: it never expires.';

  @override
  String get paywallManageSubscription => 'Manage subscription';

  @override
  String get appearanceStyle => 'Colour style';

  @override
  String get appearanceStyleStandard => 'Standard';

  @override
  String get appearanceStyleOcean => 'Ocean';

  @override
  String get appearanceStyleEmber => 'Ember';

  @override
  String get appearanceStyleMidnight => 'Midnight';

  @override
  String get appearanceStyleLocked => 'Included with Premium';

  @override
  String get appearanceStyleWallpaperOn =>
      'Colours from wallpaper are on, so colour styles don\'t show.';

  @override
  String get updateRequiredTitle => 'Update required';

  @override
  String get updateRequiredBody =>
      'This version of the app is too old to keep working reliably. Update to the latest version to continue.';

  @override
  String get updateRequiredAction => 'Update';

  @override
  String get updateRequiredFailed =>
      'Couldn\'t open the store. Update the app from your phone\'s app store.';
}
