import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// Connection status pill: the TV is connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get statusConnected;

  /// Connection status pill: the first connection attempt is running.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get statusConnecting;

  /// Connection status pill: the connection was lost and the app is trying again.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
  String get statusReconnecting;

  /// Connection status pill: every reconnect attempt failed.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get statusOffline;

  /// Connection status pill: the TV no longer accepts this phone, or its security key changed, so it must be paired again.
  ///
  /// In en, this message translates to:
  /// **'Needs pairing'**
  String get statusNeedsPairing;

  /// Connection status pill: no connection and no attempt in progress.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get statusDisconnected;

  /// Button next to the Offline status that tries to connect again.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get statusReconnectAction;

  /// Screen-reader label of the connection status pill.
  ///
  /// In en, this message translates to:
  /// **'Connection: {status}'**
  String statusSemantics(String status);

  /// Tooltip and screen-reader label of the button that closes a bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeAction;

  /// Button that finishes onboarding and opens the TV list.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onboardingGetStarted;

  /// Button on the first-run screen that opens the remote with a simulated TV, for people without a TV at hand.
  ///
  /// In en, this message translates to:
  /// **'Try demo'**
  String get onboardingTryDemo;

  /// Top-end button on onboarding cards 1–2; finishes onboarding and opens the TV list.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// Primary button on onboarding cards 1–2; shows the next card.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// Spoken page indicator of the onboarding cards (`current` and `total`: `int`).
  ///
  /// In en, this message translates to:
  /// **'Card {current} of {total}'**
  String onboardingProgress(int current, int total);

  /// Title of onboarding card 1 (connect).
  ///
  /// In en, this message translates to:
  /// **'Find your TV'**
  String get onboardingConnectTitle;

  /// Body of onboarding card 1 (connect).
  ///
  /// In en, this message translates to:
  /// **'Your phone finds your Android TV on the same Wi-Fi network. Pair once with the code your TV shows.'**
  String get onboardingConnectBody;

  /// Note on onboarding card 1 (connect): the app needs no location permission to find TVs.
  ///
  /// In en, this message translates to:
  /// **'The app only looks on your Wi-Fi network. It never asks for your location.'**
  String get onboardingConnectNote;

  /// Title of onboarding card 2 (control).
  ///
  /// In en, this message translates to:
  /// **'Control it from your phone'**
  String get onboardingControlTitle;

  /// Body of onboarding card 2 (control).
  ///
  /// In en, this message translates to:
  /// **'Swipe the touchpad or use the D-pad, change the volume and type with your phone\'s keyboard.'**
  String get onboardingControlBody;

  /// Title of onboarding card 3 (apps).
  ///
  /// In en, this message translates to:
  /// **'Open apps in one tap'**
  String get onboardingAppsTitle;

  /// Body of onboarding card 3 (apps).
  ///
  /// In en, this message translates to:
  /// **'Keep your favourite TV apps in a row on the remote and open them without searching.'**
  String get onboardingAppsBody;

  /// Title of the iOS explainer shown before the system Local Network prompt.
  ///
  /// In en, this message translates to:
  /// **'Allow local network access'**
  String get onboardingLocalNetworkTitle;

  /// Body of the iOS explainer shown before the system Local Network prompt.
  ///
  /// In en, this message translates to:
  /// **'Next, your iPhone asks to let this app find devices on your local network. Choose Allow so the app can find your TV. You can change this later in Settings → Privacy & Security → Local Network.'**
  String get onboardingLocalNetworkBody;

  /// The iOS local network explainer's only action; closes it and opens the TV list.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onboardingContinue;

  /// Label of the strip shown above every screen while the simulated demo TV is in use.
  ///
  /// In en, this message translates to:
  /// **'Demo mode'**
  String get demoBadgeLabel;

  /// Button in the demo strip that asks to leave demo mode.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get demoLeaveAction;

  /// Title of the dialog that asks to leave demo mode.
  ///
  /// In en, this message translates to:
  /// **'Leave demo?'**
  String get demoLeaveTitle;

  /// Body of the leave-demo dialog.
  ///
  /// In en, this message translates to:
  /// **'You\'ll go back to the list of TVs.'**
  String get demoLeaveMessage;

  /// Button of the leave-demo dialog that leaves demo mode.
  ///
  /// In en, this message translates to:
  /// **'Leave demo'**
  String get demoLeaveConfirm;

  /// Button of the leave-demo dialog that keeps demo mode.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get demoStay;

  /// Title of the card that shows what the simulated TV did.
  ///
  /// In en, this message translates to:
  /// **'TV preview'**
  String get tvPreviewTitle;

  /// TV preview text before any button was pressed.
  ///
  /// In en, this message translates to:
  /// **'Press a button to see what the TV would do.'**
  String get tvPreviewIdle;

  /// TV preview text after a key was tapped.
  ///
  /// In en, this message translates to:
  /// **'Pressed {key}'**
  String tvPreviewPressed(String key);

  /// TV preview text while a key is held down.
  ///
  /// In en, this message translates to:
  /// **'Holding {key}'**
  String tvPreviewHolding(String key);

  /// TV preview text after a held key was released.
  ///
  /// In en, this message translates to:
  /// **'Released {key}'**
  String tvPreviewReleased(String key);

  /// TV preview text after an app link was opened on the TV.
  ///
  /// In en, this message translates to:
  /// **'Opened {link}'**
  String tvPreviewOpened(String link);

  /// TV preview text after text was typed into the TV.
  ///
  /// In en, this message translates to:
  /// **'Typed \"{text}\"'**
  String tvPreviewTyped(String text);

  /// TV preview status: the simulated TV screen is on.
  ///
  /// In en, this message translates to:
  /// **'Screen on'**
  String get tvPreviewScreenOn;

  /// TV preview status: the simulated TV screen is off.
  ///
  /// In en, this message translates to:
  /// **'Screen off'**
  String get tvPreviewScreenOff;

  /// TV preview status: the simulated TV volume.
  ///
  /// In en, this message translates to:
  /// **'Volume {level} of {max}'**
  String tvPreviewVolume(int level, int max);

  /// TV preview status: the simulated TV is muted.
  ///
  /// In en, this message translates to:
  /// **'Muted'**
  String get tvPreviewMuted;

  /// Title of the TV discovery screen.
  ///
  /// In en, this message translates to:
  /// **'Choose your TV'**
  String get discoverTitle;

  /// Heading of the discovery screen when no TV has been found.
  ///
  /// In en, this message translates to:
  /// **'No TVs found yet'**
  String get discoverEmptyTitle;

  /// Hint under the empty discovery heading.
  ///
  /// In en, this message translates to:
  /// **'Make sure your phone and TV are on the same Wi-Fi network and the TV is turned on.'**
  String get discoverEmptyBody;

  /// Shown with a spinner while the app searches the network for TVs.
  ///
  /// In en, this message translates to:
  /// **'Looking for TVs on this Wi-Fi…'**
  String get discoverSearching;

  /// Button that restarts the search for TVs.
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get discoverScanAgain;

  /// Button on the discovery screen that opens the sheet for adding a TV by its IP address.
  ///
  /// In en, this message translates to:
  /// **'Enter IP address'**
  String get discoverEnterIp;

  /// Button on the discovery screen that opens the remote with a simulated TV.
  ///
  /// In en, this message translates to:
  /// **'Try demo'**
  String get discoverTryDemo;

  /// Button on the empty discovery screen that opens the troubleshooting steps.
  ///
  /// In en, this message translates to:
  /// **'Troubleshooting'**
  String get discoverTroubleshooting;

  /// Label on a TV in the discovery list that this phone is already paired with.
  ///
  /// In en, this message translates to:
  /// **'Paired'**
  String get discoverPaired;

  /// Label on a TV in the discovery list whose remote service is too old to control.
  ///
  /// In en, this message translates to:
  /// **'Update needed'**
  String get discoverUpdateNeeded;

  /// Heading of the discovery screen when the search failed to start.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t search for TVs'**
  String get discoverErrorTitle;

  /// Hint under the search-failed heading.
  ///
  /// In en, this message translates to:
  /// **'Check that Wi-Fi is on, then scan again.'**
  String get discoverErrorBody;

  /// Title of the sheet with steps for when no TV is found.
  ///
  /// In en, this message translates to:
  /// **'Can\'t find your TV?'**
  String get troubleshootTitle;

  /// Troubleshooting step 1.
  ///
  /// In en, this message translates to:
  /// **'Connect your phone and TV to the same Wi-Fi network (not a guest network).'**
  String get troubleshootSameWifi;

  /// Troubleshooting step 2.
  ///
  /// In en, this message translates to:
  /// **'Turn the TV on. Some TVs can\'t be found while in standby.'**
  String get troubleshootTvOn;

  /// Troubleshooting step 3.
  ///
  /// In en, this message translates to:
  /// **'On the TV, make sure \"Android TV Remote Service\" is installed and up to date in the Play Store.'**
  String get troubleshootRemoteService;

  /// Troubleshooting step shown on iPhone only.
  ///
  /// In en, this message translates to:
  /// **'On iPhone, allow Local Network access for this app in Settings → Privacy & Security → Local Network.'**
  String get troubleshootLocalNetwork;

  /// Troubleshooting step.
  ///
  /// In en, this message translates to:
  /// **'Still nothing? Restart the TV and your router, then scan again.'**
  String get troubleshootRestart;

  /// Last troubleshooting step.
  ///
  /// In en, this message translates to:
  /// **'You can also enter the TV\'s IP address. Find it on the TV under Settings → Network & Internet.'**
  String get troubleshootManualIp;

  /// Title of the sheet explaining that a TV runs an old remote service.
  ///
  /// In en, this message translates to:
  /// **'Update needed on this TV'**
  String get legacyTitle;

  /// Body of the legacy-service sheet.
  ///
  /// In en, this message translates to:
  /// **'{tvName} uses an older remote service. On the TV, open the Play Store, search for \"Android TV Remote Service\", update it, then scan again.'**
  String legacyBody(String tvName);

  /// Title of the sheet for adding a TV by its IP address.
  ///
  /// In en, this message translates to:
  /// **'Enter IP address'**
  String get manualIpTitle;

  /// Label of the IP address field.
  ///
  /// In en, this message translates to:
  /// **'TV IP address'**
  String get manualIpLabel;

  /// Example shown in the empty IP address field.
  ///
  /// In en, this message translates to:
  /// **'192.168.1.20'**
  String get manualIpHint;

  /// Help text under the IP address field.
  ///
  /// In en, this message translates to:
  /// **'Find it on the TV under Settings → Network & Internet → your network.'**
  String get manualIpHelp;

  /// Error under the IP address field when the text is not a valid IPv4 address.
  ///
  /// In en, this message translates to:
  /// **'Enter an address like 192.168.1.20'**
  String get manualIpError;

  /// Button that accepts the IP address and continues to pairing.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get manualIpContinue;

  /// Title of the pairing screen.
  ///
  /// In en, this message translates to:
  /// **'Pair your TV'**
  String get pageTitlePair;

  /// Title of the remote screen.
  ///
  /// In en, this message translates to:
  /// **'Remote'**
  String get pageTitleRemote;

  /// Title of the TV apps screen.
  ///
  /// In en, this message translates to:
  /// **'Apps'**
  String get pageTitleApps;

  /// Title of `/devices` and its hub row (was "Devices").
  ///
  /// In en, this message translates to:
  /// **'Your TVs'**
  String get pageTitleDevices;

  /// Title of the settings screen.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get pageTitleSettings;

  /// Title of the premium upgrade screen.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get pageTitlePaywall;

  /// Text shown on screens that are not built yet.
  ///
  /// In en, this message translates to:
  /// **'This screen is coming soon.'**
  String get placeholderBody;

  /// Title shown when the app is asked to open a page that does not exist.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get routeNotFoundTitle;

  /// Explanation shown on the page-not-found screen.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find that page.'**
  String get routeNotFoundBody;

  /// Button on the page-not-found screen that returns to the TV list.
  ///
  /// In en, this message translates to:
  /// **'Back to TVs'**
  String get routeNotFoundAction;

  /// Button inside the status pill that opens pairing for a TV that needs to be paired again.
  ///
  /// In en, this message translates to:
  /// **'Pair again'**
  String get statusPairAgainAction;

  /// Snackbar shown when a remote key is pressed while the TV is not connected.
  ///
  /// In en, this message translates to:
  /// **'Not connected to your TV'**
  String get remoteNotConnected;

  /// Tooltip of the TV name button on the remote screen, and title of the sheet that lists saved TVs.
  ///
  /// In en, this message translates to:
  /// **'Switch TV'**
  String get remoteSwitchTv;

  /// List item in the switch-TV sheet that opens discovery to add another TV.
  ///
  /// In en, this message translates to:
  /// **'Add a TV'**
  String get remoteAddTv;

  /// Heading of the remote screen when no TV has been chosen yet.
  ///
  /// In en, this message translates to:
  /// **'No TV selected'**
  String get remoteNoTvTitle;

  /// Button on the remote screen that opens discovery when no TV is selected.
  ///
  /// In en, this message translates to:
  /// **'Choose a TV'**
  String get remoteNoTvAction;

  /// Title of the dialog shown when a paired TV presents a different security key than before.
  ///
  /// In en, this message translates to:
  /// **'This TV\'s identity changed'**
  String get remoteIdentityChangedTitle;

  /// Body of the identity-changed dialog.
  ///
  /// In en, this message translates to:
  /// **'{tvName} presented a different security key than when you paired it. If the TV was reset or replaced, pair it again.'**
  String remoteIdentityChangedMessage(String tvName);

  /// Dialog action that dismisses the identity-changed dialog without pairing again.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get remoteNotNow;

  /// Heading of the remote screen when this phone's security key could not be loaded.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t prepare a secure connection'**
  String get remoteSessionErrorTitle;

  /// Explanation under the secure-connection error heading.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while loading this phone\'s security key.'**
  String get remoteSessionErrorBody;

  /// Button that retries preparing the connection after an error.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get remoteRetry;

  /// Name shown for the simulated demo TV.
  ///
  /// In en, this message translates to:
  /// **'Demo TV'**
  String get demoTvName;

  /// Short caption between the volume up and down keys.
  ///
  /// In en, this message translates to:
  /// **'VOL'**
  String get volumeLabel;

  /// Screen-reader label of a digit key on the remote.
  ///
  /// In en, this message translates to:
  /// **'Number {digit}'**
  String keyNumber(int digit);

  /// Screen-reader label of a key without a specific name.
  ///
  /// In en, this message translates to:
  /// **'Key {code}'**
  String keyUnknown(int code);

  /// Screen-reader label of the d-pad up.
  ///
  /// In en, this message translates to:
  /// **'Up'**
  String get keyUp;

  /// Screen-reader label of the d-pad down.
  ///
  /// In en, this message translates to:
  /// **'Down'**
  String get keyDown;

  /// Screen-reader label of the d-pad left.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get keyLeft;

  /// Screen-reader label of the d-pad right.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get keyRight;

  /// Screen-reader label of the select / OK key.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get keyOk;

  /// Screen-reader label of the back key.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get keyBack;

  /// Screen-reader label of the home key.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get keyHome;

  /// Screen-reader label of the menu key.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get keyMenu;

  /// Screen-reader label of the power key.
  ///
  /// In en, this message translates to:
  /// **'Power'**
  String get keyPower;

  /// Screen-reader label of the volume up key.
  ///
  /// In en, this message translates to:
  /// **'Volume up'**
  String get keyVolumeUp;

  /// Screen-reader label of the volume down key.
  ///
  /// In en, this message translates to:
  /// **'Volume down'**
  String get keyVolumeDown;

  /// Screen-reader label of the mute key.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get keyMute;

  /// Screen-reader label of the channel up key.
  ///
  /// In en, this message translates to:
  /// **'Channel up'**
  String get keyChannelUp;

  /// Screen-reader label of the channel down key.
  ///
  /// In en, this message translates to:
  /// **'Channel down'**
  String get keyChannelDown;

  /// Screen-reader label of the play/pause media key.
  ///
  /// In en, this message translates to:
  /// **'Play or pause'**
  String get keyPlayPause;

  /// Screen-reader label of the next media key.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get keyNext;

  /// Screen-reader label of the previous media key.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get keyPrevious;

  /// Screen-reader label of the rewind media key.
  ///
  /// In en, this message translates to:
  /// **'Rewind'**
  String get keyRewind;

  /// Screen-reader label of the fast forward media key.
  ///
  /// In en, this message translates to:
  /// **'Fast forward'**
  String get keyFastForward;

  /// Screen-reader label of the stop media key.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get keyStop;

  /// Screen-reader label of the red colour key.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get keyRed;

  /// Screen-reader label of the green colour key.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get keyGreen;

  /// Screen-reader label of the yellow colour key.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get keyYellow;

  /// Screen-reader label of the blue colour key.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get keyBlue;

  /// Screen-reader label of the TV input key.
  ///
  /// In en, this message translates to:
  /// **'TV input'**
  String get keyTvInput;

  /// Screen-reader label of the settings key of the TV.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get keySettings;

  /// Screen-reader label of the guide key.
  ///
  /// In en, this message translates to:
  /// **'Guide'**
  String get keyGuide;

  /// Screen-reader label of the info key.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get keyInfo;

  /// Screen-reader label of the captions key.
  ///
  /// In en, this message translates to:
  /// **'Captions'**
  String get keyCaptions;

  /// Screen-reader label of the search key.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get keySearch;

  /// Screen-reader label of the Enter key (confirms text on the TV).
  ///
  /// In en, this message translates to:
  /// **'Enter'**
  String get keyEnter;

  /// Screen-reader label of the key that deletes the character before the cursor on the TV.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get keyDelete;

  /// Label of the remote key that opens the keyboard sheet for typing on the TV.
  ///
  /// In en, this message translates to:
  /// **'Keyboard'**
  String get keyKeyboard;

  /// Shown while the app connects to the TV to start pairing.
  ///
  /// In en, this message translates to:
  /// **'Connecting to {tvName}…'**
  String pairStarting(String tvName);

  /// Instruction above the pairing code field.
  ///
  /// In en, this message translates to:
  /// **'Enter the code shown on {tvName}'**
  String pairEnterCode(String tvName);

  /// Label of the pairing code field.
  ///
  /// In en, this message translates to:
  /// **'Pairing code'**
  String get pairCodeLabel;

  /// Countdown under the pairing code field.
  ///
  /// In en, this message translates to:
  /// **'Code expires in {seconds} s'**
  String pairExpiresIn(int seconds);

  /// Button that fills the pairing code field from the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste code'**
  String get pairPaste;

  /// Message shown when Paste code finds no pairing code on the clipboard.
  ///
  /// In en, this message translates to:
  /// **'There\'s no 6-character code on the clipboard.'**
  String get pairNothingToPaste;

  /// Error under the pairing code field when the code fails its checksum.
  ///
  /// In en, this message translates to:
  /// **'That code doesn\'t match. Check the code on your TV and enter it again.'**
  String get pairCodeMismatch;

  /// Shown while the TV checks the pairing code.
  ///
  /// In en, this message translates to:
  /// **'Checking the code…'**
  String get pairVerifying;

  /// Title shown when the pairing code timed out.
  ///
  /// In en, this message translates to:
  /// **'The code expired'**
  String get pairExpiredTitle;

  /// Explanation shown when the pairing code timed out.
  ///
  /// In en, this message translates to:
  /// **'Ask the TV for a new code and enter it within 60 seconds.'**
  String get pairExpiredBody;

  /// Button that starts pairing again to get a fresh code from the TV.
  ///
  /// In en, this message translates to:
  /// **'Get a new code'**
  String get pairNewCode;

  /// Button that starts pairing again after an error.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get pairTryAgain;

  /// Button on the pairing error screen that opens the troubleshooting steps.
  ///
  /// In en, this message translates to:
  /// **'Troubleshooting'**
  String get pairTroubleshooting;

  /// Title shown when the TV could not be reached for pairing.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach {tvName}'**
  String pairCantReachTitle(String tvName);

  /// Explanation shown when the TV could not be reached or did not answer.
  ///
  /// In en, this message translates to:
  /// **'Make sure the TV is on and on the same Wi-Fi network as your phone.'**
  String get pairCantReachBody;

  /// Title shown when the TV stopped answering during pairing.
  ///
  /// In en, this message translates to:
  /// **'{tvName} didn\'t respond'**
  String pairNoResponseTitle(String tvName);

  /// Title shown when the TV rejected the pairing code.
  ///
  /// In en, this message translates to:
  /// **'The TV didn\'t accept the code'**
  String get pairRejectedTitle;

  /// Explanation shown when the TV rejected the pairing code.
  ///
  /// In en, this message translates to:
  /// **'Get a new code and enter it exactly as shown.'**
  String get pairRejectedBody;

  /// Title shown for an unexpected pairing error.
  ///
  /// In en, this message translates to:
  /// **'Pairing didn\'t work'**
  String get pairErrorTitle;

  /// Explanation shown for an unexpected pairing error.
  ///
  /// In en, this message translates to:
  /// **'Something unexpected happened. Try again.'**
  String get pairErrorBody;

  /// Title shown when the phone could not prepare its secure identity for pairing.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t prepare a secure connection'**
  String get pairIdentityTitle;

  /// Title shown when pairing worked but the TV could not be saved.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save this TV'**
  String get pairSaveFailedTitle;

  /// Title shown when the pairing screen is opened for a TV that is not known.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find this TV'**
  String get pairNotFoundTitle;

  /// Explanation shown when the pairing screen is opened for a TV that is not known.
  ///
  /// In en, this message translates to:
  /// **'Go back to the list of TVs and choose it again.'**
  String get pairNotFoundBody;

  /// Accessibility label of the tab bar that switches between the touchpad, D-pad and number pad.
  ///
  /// In en, this message translates to:
  /// **'Control style'**
  String get remotePadTabsLabel;

  /// Tab label: the swipe-and-tap touchpad control style.
  ///
  /// In en, this message translates to:
  /// **'Touchpad'**
  String get remotePadTouchpad;

  /// Tab label: the directional-pad control style.
  ///
  /// In en, this message translates to:
  /// **'D-pad'**
  String get remotePadDpad;

  /// Tab label: the number pad (digits 0 to 9).
  ///
  /// In en, this message translates to:
  /// **'Numbers'**
  String get remotePadNumbers;

  /// Screen-reader label of the touchpad area.
  ///
  /// In en, this message translates to:
  /// **'Touchpad'**
  String get touchpadLabel;

  /// Screen-reader hint of the touchpad area that explains its gestures.
  ///
  /// In en, this message translates to:
  /// **'Swipe to move, tap to select, tap with two fingers to go back.'**
  String get touchpadHint;

  /// Short hint drawn on the touchpad while it is idle.
  ///
  /// In en, this message translates to:
  /// **'Swipe to move · Tap to select'**
  String get touchpadIdleHint;

  /// Short visible label of the channel up/down rocker.
  ///
  /// In en, this message translates to:
  /// **'CH'**
  String get channelLabel;

  /// The TV volume level shown on the volume rocker.
  ///
  /// In en, this message translates to:
  /// **'{level}'**
  String remoteVolumeValue(int level);

  /// Shown on the volume rocker instead of the level while the TV is muted.
  ///
  /// In en, this message translates to:
  /// **'Muted'**
  String get remoteMutedValue;

  /// Screen-reader description of the TV volume.
  ///
  /// In en, this message translates to:
  /// **'Volume {level} of {max}'**
  String remoteVolumeSemantics(int level, int max);

  /// Screen-reader description of the TV volume while it is muted.
  ///
  /// In en, this message translates to:
  /// **'Volume muted'**
  String get remoteVolumeMutedSemantics;

  /// Screen-reader label of the row of app shortcuts.
  ///
  /// In en, this message translates to:
  /// **'Apps on your TV'**
  String get quickAccessAppsLabel;

  /// Screen-reader label of the row of red, green, yellow and blue keys.
  ///
  /// In en, this message translates to:
  /// **'Colour keys'**
  String get quickAccessColourLabel;

  /// Screen-reader label of the row of playback keys.
  ///
  /// In en, this message translates to:
  /// **'Media keys'**
  String get quickAccessMediaLabel;

  /// Screen-reader label of an app shortcut: opens the app on the TV.
  ///
  /// In en, this message translates to:
  /// **'Open {app}'**
  String quickAppOpen(String app);

  /// Screen-reader label of the app shortcut for the app that is open on the TV right now.
  ///
  /// In en, this message translates to:
  /// **'{app}, now on TV'**
  String quickAppNowOnTv(String app);

  /// Snackbar shown when the power key is tapped instead of held.
  ///
  /// In en, this message translates to:
  /// **'Hold to turn the TV on or off'**
  String get powerHoldHint;

  /// Snackbar shown while the app sends the wake-up signal to the TV.
  ///
  /// In en, this message translates to:
  /// **'Waking {tvName}…'**
  String powerWaking(String tvName);

  /// Error shown when the Wake-on-LAN signal could not be sent.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the wake-up signal. Make sure your phone is on the same Wi-Fi as the TV.'**
  String get powerWakeFailed;

  /// Shown on iOS when the TV is off and the app cannot wake it: the user must use the TV remote.
  ///
  /// In en, this message translates to:
  /// **'Turn the TV on with its own remote. This app reconnects by itself.'**
  String get powerTurnOnWithTvRemote;

  /// Title of the sheet that asks for the TV MAC address so the phone can wake it.
  ///
  /// In en, this message translates to:
  /// **'Turn on {tvName} from your phone'**
  String wolSetupTitle(String tvName);

  /// Explains where to find the TV MAC address, in the Wake-on-LAN setup sheet.
  ///
  /// In en, this message translates to:
  /// **'Your phone can wake the TV over the network with its MAC address. On the TV, open Settings → System → About → Status (or Settings → Network & Internet) and copy the Wi-Fi or Ethernet MAC address.'**
  String get wolSetupBody;

  /// Warning in the Wake-on-LAN setup sheet: the Bluetooth address does not work.
  ///
  /// In en, this message translates to:
  /// **'Use the Wi-Fi or Ethernet MAC address, not the Bluetooth one.'**
  String get wolNotBluetooth;

  /// Caveat in the Wake-on-LAN setup sheet.
  ///
  /// In en, this message translates to:
  /// **'Some TVs can\'t be woken when they\'re fully off or in deep standby.'**
  String get wolMayNotWork;

  /// Label of the MAC address text field.
  ///
  /// In en, this message translates to:
  /// **'MAC address'**
  String get wolMacLabel;

  /// Example MAC address shown as the hint of the MAC address field.
  ///
  /// In en, this message translates to:
  /// **'AA:BB:CC:DD:EE:FF'**
  String get wolMacHint;

  /// Validation error under the MAC address field.
  ///
  /// In en, this message translates to:
  /// **'Enter 6 pairs of letters or digits, like AA:BB:CC:DD:EE:FF'**
  String get wolMacError;

  /// Button in the Wake-on-LAN setup sheet: saves the MAC address and sends the wake-up signal.
  ///
  /// In en, this message translates to:
  /// **'Save and turn on'**
  String get wolSaveAndWake;

  /// Error shown when the MAC address could not be saved.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the MAC address. Try again.'**
  String get wolSaveFailed;

  /// Title of the keyboard sheet.
  ///
  /// In en, this message translates to:
  /// **'Type on your TV'**
  String get keyboardTitle;

  /// Label of the text field in the keyboard sheet.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get keyboardFieldLabel;

  /// Hint inside the empty text field of the keyboard sheet.
  ///
  /// In en, this message translates to:
  /// **'Start typing…'**
  String get keyboardHint;

  /// Explains that a text field must be focused on the TV before typing works.
  ///
  /// In en, this message translates to:
  /// **'Select a text field on the TV first, like the search box.'**
  String get keyboardTvHint;

  /// Button that empties the text field on the TV.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get keyboardClear;

  /// Button in the keyboard sheet that opens the search screen on the TV.
  ///
  /// In en, this message translates to:
  /// **'Open search on TV'**
  String get keyboardOpenTvSearch;

  /// Inline message in the keyboard sheet while the TV is not connected.
  ///
  /// In en, this message translates to:
  /// **'Not connected to your TV. What you type isn\'t sent.'**
  String get keyboardNotConnected;

  /// Screen-reader label of the dimmed Theater Mode overlay.
  ///
  /// In en, this message translates to:
  /// **'Screen dimmed. Touch to brighten.'**
  String get theaterWakeLabel;

  /// Dismiss action of confirmation dialogs.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Save buttons (Edit TV, shortcut editor).
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// Snackbar action after removing an app.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get commonUndo;

  /// Button that retries loading a list that couldn't be read.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonRetry;

  /// Row in the TV switcher sheet → Your TVs.
  ///
  /// In en, this message translates to:
  /// **'Manage TVs'**
  String get remoteManageTvs;

  /// Last tile of the quick row → Apps screen.
  ///
  /// In en, this message translates to:
  /// **'All apps'**
  String get quickAccessAllApps;

  /// Title of `/apps/manage`; Apps screen action.
  ///
  /// In en, this message translates to:
  /// **'Edit apps'**
  String get pageTitleManageApps;

  /// Edit TV title while loading or when the TV isn't found.
  ///
  /// In en, this message translates to:
  /// **'Edit TV'**
  String get pageTitleEditDevice;

  /// Page title and hub row.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get pageTitleAppearance;

  /// Page title and hub row.
  ///
  /// In en, this message translates to:
  /// **'Remote layout'**
  String get pageTitleRemoteLayout;

  /// Page title and hub row.
  ///
  /// In en, this message translates to:
  /// **'Remote behaviour'**
  String get pageTitleRemoteBehaviour;

  /// Page title and hub row.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get pageTitleHelp;

  /// Page title and hub row.
  ///
  /// In en, this message translates to:
  /// **'About this app'**
  String get pageTitleAbout;

  /// Label of the Apps screen search field.
  ///
  /// In en, this message translates to:
  /// **'Search apps'**
  String get appsSearchLabel;

  /// Header of the shortcuts grid.
  ///
  /// In en, this message translates to:
  /// **'Your apps'**
  String get appsYourApps;

  /// Header of catalogue matches while searching.
  ///
  /// In en, this message translates to:
  /// **'More apps'**
  String get appsMoreApps;

  /// Search with no results.
  ///
  /// In en, this message translates to:
  /// **'No apps match \"{query}\".'**
  String appsNoMatches(String query);

  /// Empty Apps screen.
  ///
  /// In en, this message translates to:
  /// **'No apps yet'**
  String get appsEmptyTitle;

  /// Apps screen, when the saved shortcuts can't be read.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your apps.'**
  String get appsLoadFailed;

  /// Empty Apps screen.
  ///
  /// In en, this message translates to:
  /// **'Add the apps you use on your TV to open them with one tap.'**
  String get appsEmptyBody;

  /// Empty Apps screen button → Edit apps.
  ///
  /// In en, this message translates to:
  /// **'Add apps'**
  String get appsEmptyAction;

  /// App bar action of Edit apps.
  ///
  /// In en, this message translates to:
  /// **'Add app'**
  String get manageAppsAdd;

  /// Overflow menu item.
  ///
  /// In en, this message translates to:
  /// **'Reset to suggested apps'**
  String get manageAppsReset;

  /// Reset confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Reset your apps?'**
  String get manageAppsResetTitle;

  /// Reset confirmation body.
  ///
  /// In en, this message translates to:
  /// **'Your list goes back to the suggested apps for your region. Shortcuts you added or changed are removed.'**
  String get manageAppsResetBody;

  /// Destructive reset action.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get manageAppsResetConfirm;

  /// Hint above the list.
  ///
  /// In en, this message translates to:
  /// **'Drag the handle to change the order. The remote shows your apps in this order.'**
  String get manageAppsReorderHint;

  /// Semantics label of a row's drag handle.
  ///
  /// In en, this message translates to:
  /// **'Reorder {app}'**
  String manageAppsDragHandle(String app);

  /// Tooltip of a row's edit button.
  ///
  /// In en, this message translates to:
  /// **'Edit {app}'**
  String manageAppsEdit(String app);

  /// Tooltip of a row's remove button.
  ///
  /// In en, this message translates to:
  /// **'Remove {app}'**
  String manageAppsRemove(String app);

  /// Snackbar after removing (with Undo).
  ///
  /// In en, this message translates to:
  /// **'{app} removed'**
  String manageAppsRemoved(String app);

  /// Empty Edit apps list.
  ///
  /// In en, this message translates to:
  /// **'No apps on your list. Add one to see it on the remote.'**
  String get manageAppsEmpty;

  /// Any shortcut write failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save your apps. Try again.'**
  String get manageAppsSaveFailed;

  /// Add sheet title.
  ///
  /// In en, this message translates to:
  /// **'Add an app'**
  String get addAppTitle;

  /// Add sheet search field.
  ///
  /// In en, this message translates to:
  /// **'Search apps or enter an app ID'**
  String get addAppSearchLabel;

  /// First row of the add sheet.
  ///
  /// In en, this message translates to:
  /// **'Create a custom shortcut'**
  String get addAppCustom;

  /// Section header.
  ///
  /// In en, this message translates to:
  /// **'Recently used on your TV'**
  String get addAppRecentTitle;

  /// Empty recent section.
  ///
  /// In en, this message translates to:
  /// **'Apps you open on your TV show up here.'**
  String get addAppRecentEmpty;

  /// Section header (catalogue for the region).
  ///
  /// In en, this message translates to:
  /// **'Suggested apps'**
  String get addAppPopularTitle;

  /// Search with no results.
  ///
  /// In en, this message translates to:
  /// **'No apps found. If you know the app\'s ID, type it to add it.'**
  String get addAppNoResults;

  /// Row that adds a typed package name.
  ///
  /// In en, this message translates to:
  /// **'Add app ID \"{package}\"'**
  String addAppById(String package);

  /// Snackbar after adding.
  ///
  /// In en, this message translates to:
  /// **'{app} added'**
  String addAppAdded(String app);

  /// Subtitle of a disabled row.
  ///
  /// In en, this message translates to:
  /// **'Already on your list'**
  String get addAppAlreadyAdded;

  /// Editor title (create).
  ///
  /// In en, this message translates to:
  /// **'New shortcut'**
  String get shortcutNewTitle;

  /// Editor title (edit).
  ///
  /// In en, this message translates to:
  /// **'Edit shortcut'**
  String get shortcutEditTitle;

  /// Editor field.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get shortcutNameLabel;

  /// Editor validation.
  ///
  /// In en, this message translates to:
  /// **'Enter a name of up to 30 characters.'**
  String get shortcutNameError;

  /// Editor field.
  ///
  /// In en, this message translates to:
  /// **'App ID'**
  String get shortcutPackageLabel;

  /// Editor field hint.
  ///
  /// In en, this message translates to:
  /// **'com.example.app'**
  String get shortcutPackageHint;

  /// Editor helper text.
  ///
  /// In en, this message translates to:
  /// **'The app\'s ID on the TV. It\'s in the app\'s Play Store web address, after \"id=\".'**
  String get shortcutPackageHelp;

  /// Editor validation.
  ///
  /// In en, this message translates to:
  /// **'Enter an app ID like com.example.app.'**
  String get shortcutPackageError;

  /// Editor validation.
  ///
  /// In en, this message translates to:
  /// **'This app is already on your list.'**
  String get shortcutPackageTaken;

  /// Editor group label.
  ///
  /// In en, this message translates to:
  /// **'Tile colour'**
  String get shortcutColourLabel;

  /// Colour choice: no custom colour.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get shortcutColourDefault;

  /// Colour swatch name (semantics).
  ///
  /// In en, this message translates to:
  /// **'Slate'**
  String get shortcutColourSlate;

  /// Colour swatch name (semantics).
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get shortcutColourBlue;

  /// Colour swatch name (semantics).
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get shortcutColourTeal;

  /// Colour swatch name (semantics).
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get shortcutColourGreen;

  /// Colour swatch name (semantics).
  ///
  /// In en, this message translates to:
  /// **'Amber'**
  String get shortcutColourAmber;

  /// Colour swatch name (semantics).
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get shortcutColourOrange;

  /// Colour swatch name (semantics).
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get shortcutColourRed;

  /// Colour swatch name (semantics).
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get shortcutColourPurple;

  /// Editor group label.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get shortcutIconLabel;

  /// Icon choice: monogram.
  ///
  /// In en, this message translates to:
  /// **'First letter'**
  String get shortcutIconLetter;

  /// Generic icon name.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get shortcutIconApp;

  /// Icon name.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get shortcutIconMovies;

  /// Icon name.
  ///
  /// In en, this message translates to:
  /// **'Live TV'**
  String get shortcutIconLive;

  /// Icon name.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get shortcutIconSports;

  /// Icon name.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get shortcutIconMusic;

  /// Icon name.
  ///
  /// In en, this message translates to:
  /// **'Kids'**
  String get shortcutIconKids;

  /// Icon name.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get shortcutIconNews;

  /// Icon name.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get shortcutIconGames;

  /// Icon name.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get shortcutIconLearning;

  /// Label of the live preview tile.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get shortcutPreview;

  /// Snackbar after editing.
  ///
  /// In en, this message translates to:
  /// **'Shortcut saved'**
  String get shortcutSaved;

  /// Empty Your TVs.
  ///
  /// In en, this message translates to:
  /// **'No TVs yet'**
  String get devicesEmptyTitle;

  /// Your TVs and Edit TV, when the saved TVs can't be read.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your TVs.'**
  String get devicesLoadFailed;

  /// Empty Your TVs.
  ///
  /// In en, this message translates to:
  /// **'Pair a TV to control it from this phone.'**
  String get devicesEmptyBody;

  /// Marker on the session's TV.
  ///
  /// In en, this message translates to:
  /// **'In use'**
  String get devicesInUse;

  /// Semantics/tooltip of a TV row.
  ///
  /// In en, this message translates to:
  /// **'Edit {tvName}'**
  String devicesEditTv(String tvName);

  /// Nickname field.
  ///
  /// In en, this message translates to:
  /// **'Name on this phone'**
  String get editDeviceNameLabel;

  /// Nickname helper.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use the TV\'s own name, {tvName}.'**
  String editDeviceNameHelp(String tvName);

  /// Nickname validation.
  ///
  /// In en, this message translates to:
  /// **'Use 40 characters or fewer.'**
  String get editDeviceNameError;

  /// MAC section header.
  ///
  /// In en, this message translates to:
  /// **'Turn on from your phone'**
  String get editDeviceWolTitle;

  /// MAC section text.
  ///
  /// In en, this message translates to:
  /// **'Add the TV\'s MAC address so the power key can wake it from standby.'**
  String get editDeviceWolBody;

  /// Link → MAC help sheet.
  ///
  /// In en, this message translates to:
  /// **'Where do I find it?'**
  String get editDeviceWolHelp;

  /// IOS without the entitlement.
  ///
  /// In en, this message translates to:
  /// **'Turning the TV on from an iPhone isn\'t available yet. You can still save the address.'**
  String get editDeviceWolUnavailable;

  /// MAC field: over-long input.
  ///
  /// In en, this message translates to:
  /// **'That\'s longer than a MAC address. Check what you pasted.'**
  String get wolMacTooLong;

  /// MAC help sheet title.
  ///
  /// In en, this message translates to:
  /// **'Find the TV\'s MAC address'**
  String get wolHelpTitle;

  /// Edit TV info line.
  ///
  /// In en, this message translates to:
  /// **'Last address: {host}'**
  String editDeviceLastAddress(String host);

  /// Snackbar after saving.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get editDeviceSaved;

  /// Snackbar on write failure.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save. Try again.'**
  String get editDeviceSaveFailed;

  /// Destructive button.
  ///
  /// In en, this message translates to:
  /// **'Remove TV'**
  String get editDeviceRemove;

  /// Snackbar when removing a TV fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t remove this TV. Try again.'**
  String get editDeviceRemoveFailed;

  /// Confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Remove {tvName}?'**
  String editDeviceRemoveTitle(String tvName);

  /// Confirmation body.
  ///
  /// In en, this message translates to:
  /// **'This phone forgets the TV and its settings. To use it again, pair it with a new code. The TV may still list this phone.'**
  String get editDeviceRemoveBody;

  /// Destructive confirm action.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get editDeviceRemoveConfirm;

  /// Snackbar after removing.
  ///
  /// In en, this message translates to:
  /// **'{tvName} removed'**
  String editDeviceRemoved(String tvName);

  /// Edit TV for an unknown name.
  ///
  /// In en, this message translates to:
  /// **'This TV isn\'t saved on this phone anymore.'**
  String get editDeviceNotFound;

  /// Action on the not-found state.
  ///
  /// In en, this message translates to:
  /// **'Back to your TVs'**
  String get editDeviceBackToTvs;

  /// Discovery: a merge or host update failed hard.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open this TV. Try again.'**
  String get discoverOpenFailed;

  /// Hub section header.
  ///
  /// In en, this message translates to:
  /// **'Remote'**
  String get settingsSectionRemote;

  /// Hub section header.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get settingsSectionApp;

  /// Hub section header.
  ///
  /// In en, this message translates to:
  /// **'Help and feedback'**
  String get settingsSectionSupport;

  /// Hub section header.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsSectionAbout;

  /// Hub row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Touchpad or D-pad, and the row of keys above it'**
  String get settingsRemoteLayoutSubtitle;

  /// Hub row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Vibration, Smooth Press, screen and keyboard'**
  String get settingsRemoteBehaviourSubtitle;

  /// Hub row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose and order your app shortcuts'**
  String get settingsAppsSubtitle;

  /// Hub row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Rename, remove, or turn on from your phone'**
  String get settingsDevicesSubtitle;

  /// Hub row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Theme and language'**
  String get settingsAppearanceSubtitle;

  /// Hub row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Common questions and troubleshooting'**
  String get settingsHelpSubtitle;

  /// Hub row; Help page button.
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get settingsFeedback;

  /// Hub row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Write to us by email'**
  String get settingsFeedbackSubtitle;

  /// Hub row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Version and licences'**
  String get settingsAboutSubtitle;

  /// Hub row (external link).
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get settingsPrivacy;

  /// Hub row (external link).
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get settingsTerms;

  /// Semantics hint of external-link rows.
  ///
  /// In en, this message translates to:
  /// **'Opens in your browser'**
  String get settingsOpensInBrowser;

  /// Link failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the page. Check your internet connection and try again.'**
  String get settingsLinkFailed;

  /// Group label.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get appearanceTheme;

  /// Theme choice.
  ///
  /// In en, this message translates to:
  /// **'Same as phone'**
  String get appearanceThemeSystem;

  /// Theme choice.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get appearanceThemeLight;

  /// Theme choice.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get appearanceThemeDark;

  /// Switch title.
  ///
  /// In en, this message translates to:
  /// **'Colours from wallpaper'**
  String get appearanceDynamicColour;

  /// Switch subtitle.
  ///
  /// In en, this message translates to:
  /// **'Use your phone\'s wallpaper colours in the app.'**
  String get appearanceDynamicColourSubtitle;

  /// Group label.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get appearanceLanguage;

  /// Language choice: follow the system.
  ///
  /// In en, this message translates to:
  /// **'Same as phone'**
  String get appearanceLanguageSystem;

  /// Header over the preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get layoutPreviewTitle;

  /// Semantics label of the preview.
  ///
  /// In en, this message translates to:
  /// **'Preview of the remote with these choices'**
  String get layoutPreviewSemantics;

  /// Group label.
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get layoutNavigation;

  /// Under Touchpad (title reuses `remotePadTouchpad`).
  ///
  /// In en, this message translates to:
  /// **'Swipe to move, tap to select.'**
  String get layoutTouchpadSubtitle;

  /// Under D-pad (title reuses `remotePadDpad`).
  ///
  /// In en, this message translates to:
  /// **'Arrow keys around an OK button, like a TV remote.'**
  String get layoutDpadSubtitle;

  /// Group label.
  ///
  /// In en, this message translates to:
  /// **'Row above the pad'**
  String get layoutQuickAccess;

  /// Choice title.
  ///
  /// In en, this message translates to:
  /// **'App shortcuts'**
  String get layoutQuickApps;

  /// Choice subtitle.
  ///
  /// In en, this message translates to:
  /// **'Open your TV apps with one tap.'**
  String get layoutQuickAppsSubtitle;

  /// Under Colour keys (title reuses `quickAccessColourLabel`).
  ///
  /// In en, this message translates to:
  /// **'Red, green, yellow and blue keys.'**
  String get layoutQuickColourSubtitle;

  /// Under Media keys (title reuses `quickAccessMediaLabel`).
  ///
  /// In en, this message translates to:
  /// **'Previous, rewind, play or pause, fast-forward and next.'**
  String get layoutQuickMediaSubtitle;

  /// Choice title.
  ///
  /// In en, this message translates to:
  /// **'Nothing'**
  String get layoutQuickNone;

  /// Choice subtitle.
  ///
  /// In en, this message translates to:
  /// **'More room for the touchpad or D-pad.'**
  String get layoutQuickNoneSubtitle;

  /// Switch.
  ///
  /// In en, this message translates to:
  /// **'Vibrate on key press'**
  String get behaviourHaptics;

  /// Switch subtitle.
  ///
  /// In en, this message translates to:
  /// **'A short vibration when a key reaches the TV.'**
  String get behaviourHapticsSubtitle;

  /// Switch.
  ///
  /// In en, this message translates to:
  /// **'Smooth Press'**
  String get behaviourSmoothPress;

  /// Switch subtitle.
  ///
  /// In en, this message translates to:
  /// **'Holding volume, channel or arrow keys acts like holding a key on a TV remote. When off, holding repeats the key.'**
  String get behaviourSmoothPressSubtitle;

  /// Switch.
  ///
  /// In en, this message translates to:
  /// **'Keep screen on'**
  String get behaviourKeepAwake;

  /// Switch subtitle.
  ///
  /// In en, this message translates to:
  /// **'Your phone\'s screen stays on while the remote is open.'**
  String get behaviourKeepAwakeSubtitle;

  /// Switch.
  ///
  /// In en, this message translates to:
  /// **'Theater mode'**
  String get behaviourTheater;

  /// Switch subtitle.
  ///
  /// In en, this message translates to:
  /// **'Dims your phone after 30 seconds without a touch. The first touch only brightens it.'**
  String get behaviourTheaterSubtitle;

  /// Switch.
  ///
  /// In en, this message translates to:
  /// **'Open keyboard automatically'**
  String get behaviourAutoKeyboard;

  /// Switch subtitle.
  ///
  /// In en, this message translates to:
  /// **'Opens the keyboard when the TV asks for text, like in a search box.'**
  String get behaviourAutoKeyboardSubtitle;

  /// Help card title.
  ///
  /// In en, this message translates to:
  /// **'Can\'t connect?'**
  String get helpCantConnectTitle;

  /// Help card text.
  ///
  /// In en, this message translates to:
  /// **'Go through the checks one at a time. Most problems come from the Wi-Fi network or the TV\'s remote service.'**
  String get helpCantConnectBody;

  /// Opens the troubleshooting sheet.
  ///
  /// In en, this message translates to:
  /// **'Show troubleshooting steps'**
  String get helpTroubleshootingAction;

  /// FAQ header.
  ///
  /// In en, this message translates to:
  /// **'Common questions'**
  String get helpFaqTitle;

  /// Header above Send feedback.
  ///
  /// In en, this message translates to:
  /// **'Still stuck?'**
  String get helpStillStuck;

  /// FAQ question.
  ///
  /// In en, this message translates to:
  /// **'Which TVs does this app work with?'**
  String get faqTvsQ;

  /// FAQ answer.
  ///
  /// In en, this message translates to:
  /// **'TVs and streaming boxes that run Android TV or Google TV, on the same Wi-Fi network as your phone. TVs with other systems, such as Samsung (Tizen), LG (webOS), Roku or Fire TV, can\'t be controlled by this app.'**
  String get faqTvsA;

  /// FAQ question.
  ///
  /// In en, this message translates to:
  /// **'My TV isn\'t in the list.'**
  String get faqNotFoundQ;

  /// FAQ answer.
  ///
  /// In en, this message translates to:
  /// **'Make sure the TV is on and connected to the same Wi-Fi as your phone, and that \"Android TV Remote Service\" is up to date on the TV. You can also add the TV by its IP address. The troubleshooting steps go through each check.'**
  String get faqNotFoundA;

  /// FAQ question.
  ///
  /// In en, this message translates to:
  /// **'Why does the TV ask for a code again?'**
  String get faqCodeQ;

  /// FAQ answer.
  ///
  /// In en, this message translates to:
  /// **'Pairing makes the TV and this phone trust each other. Clearing the app\'s data, reinstalling the app or resetting the TV removes that trust, so you pair once more with a new code.'**
  String get faqCodeA;

  /// FAQ question.
  ///
  /// In en, this message translates to:
  /// **'Why can\'t the app turn my TV on?'**
  String get faqPowerQ;

  /// FAQ answer.
  ///
  /// In en, this message translates to:
  /// **'A TV that is fully off can\'t hear the app. The app can send a wake-up signal if you add the TV\'s MAC address under Settings → Your TVs, but some TVs ignore it in deep standby. On iPhone this isn\'t available yet.'**
  String get faqPowerA;

  /// FAQ question.
  ///
  /// In en, this message translates to:
  /// **'What I type doesn\'t show up on the TV.'**
  String get faqTypingQ;

  /// FAQ answer.
  ///
  /// In en, this message translates to:
  /// **'Select a text field on the TV first, such as a search box. When the TV asks for text, the keyboard opens on your phone by itself.'**
  String get faqTypingA;

  /// FAQ question.
  ///
  /// In en, this message translates to:
  /// **'An app shortcut doesn\'t open.'**
  String get faqAppQ;

  /// FAQ answer.
  ///
  /// In en, this message translates to:
  /// **'The app has to be installed on the TV. Some apps have a different version in each country: add the right one by its app ID under Settings → Apps.'**
  String get faqAppA;

  /// FAQ question.
  ///
  /// In en, this message translates to:
  /// **'What does the app keep about my TV?'**
  String get faqPrivacyQ;

  /// FAQ answer.
  ///
  /// In en, this message translates to:
  /// **'Your TV\'s name, network address and MAC address stay on this phone. The app can send anonymous usage statistics and crash reports, which never include them. You can turn each on or off in Settings → Privacy choices.'**
  String get faqPrivacyA;

  /// FAQ question after the privacy question: what happens to saved TVs on a new or restored phone.
  ///
  /// In en, this message translates to:
  /// **'I moved to a new phone. Where are my TVs?'**
  String get faqNewPhoneQ;

  /// FAQ answer. Backups and phone transfer never carry saved TVs, so keep the promise exact.
  ///
  /// In en, this message translates to:
  /// **'Your TVs and their pairing stay on the phone you paired them with. They aren\'t copied by backups or when you move to a new phone, so pair each TV again on the new phone.'**
  String get faqNewPhoneA;

  /// About page.
  ///
  /// In en, this message translates to:
  /// **'Version {version} ({build})'**
  String aboutVersion(String version, String build);

  /// About page when package info fails.
  ///
  /// In en, this message translates to:
  /// **'Version unavailable'**
  String get aboutVersionUnknown;

  /// About row → `showLicensePage`.
  ///
  /// In en, this message translates to:
  /// **'Open-source licences'**
  String get aboutLicences;

  /// About page credit.
  ///
  /// In en, this message translates to:
  /// **'Talks to your TV over Wi-Fi with the Android TV Remote protocol. Its message formats come from the open-source androidtvremote2 project.'**
  String get aboutProtocol;

  /// About page disclaimer.
  ///
  /// In en, this message translates to:
  /// **'Android TV and Google TV are trademarks of Google LLC. This app isn\'t made or endorsed by Google.'**
  String get aboutTrademark;

  /// Feedback dialog title.
  ///
  /// In en, this message translates to:
  /// **'Send feedback?'**
  String get feedbackTitle;

  /// Feedback dialog body.
  ///
  /// In en, this message translates to:
  /// **'Your email app opens with a message to us. It includes the app version and your phone\'s system version, and nothing about your TV.'**
  String get feedbackBody;

  /// Feedback dialog primary action.
  ///
  /// In en, this message translates to:
  /// **'Write email'**
  String get feedbackConfirm;

  /// Email subject.
  ///
  /// In en, this message translates to:
  /// **'Feedback on {appName} {version}'**
  String feedbackSubject(String appName, String version);

  /// First line of the email body.
  ///
  /// In en, this message translates to:
  /// **'Write your message here.'**
  String get feedbackPrompt;

  /// Snackbar when mailto can't open.
  ///
  /// In en, this message translates to:
  /// **'No email app found. Write to us at {email}.'**
  String feedbackNoEmailApp(String email);

  /// Hub Premium row, free user.
  ///
  /// In en, this message translates to:
  /// **'No ads and extra colour styles'**
  String get settingsPremiumSubtitle;

  /// Hub Premium row, Premium user.
  ///
  /// In en, this message translates to:
  /// **'You have Premium. Thank you!'**
  String get settingsPremiumActiveSubtitle;

  /// Page title and hub row.
  ///
  /// In en, this message translates to:
  /// **'Privacy choices'**
  String get pageTitlePrivacyChoices;

  /// Hub row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Usage statistics, crash reports and ads'**
  String get settingsPrivacyChoicesSubtitle;

  /// About row, dev flavor only.
  ///
  /// In en, this message translates to:
  /// **'Send a test crash report'**
  String get aboutTestCrash;

  /// Snackbar after the dev test crash.
  ///
  /// In en, this message translates to:
  /// **'Test crash report sent. It shows in Crashlytics within a few minutes.'**
  String get aboutTestCrashSent;

  /// Page intro.
  ///
  /// In en, this message translates to:
  /// **'Choose what the app may share. Your TV\'s name, network address and MAC address never leave this phone.'**
  String get privacyIntro;

  /// Section header.
  ///
  /// In en, this message translates to:
  /// **'Help improve the app'**
  String get privacySectionImprove;

  /// Switch.
  ///
  /// In en, this message translates to:
  /// **'Share usage statistics'**
  String get privacyUsageTitle;

  /// Switch subtitle.
  ///
  /// In en, this message translates to:
  /// **'Anonymous counts of the screens and features you use. Never what you type or anything about your TV.'**
  String get privacyUsageSubtitle;

  /// Switch.
  ///
  /// In en, this message translates to:
  /// **'Share crash reports'**
  String get privacyCrashTitle;

  /// Switch subtitle.
  ///
  /// In en, this message translates to:
  /// **'Sent when something goes wrong, so it can be fixed. Names, addresses and codes are removed first.'**
  String get privacyCrashSubtitle;

  /// Note when Firebase is off.
  ///
  /// In en, this message translates to:
  /// **'This build of the app doesn\'t send usage statistics or crash reports.'**
  String get privacyServicesOff;

  /// Section header.
  ///
  /// In en, this message translates to:
  /// **'Ads'**
  String get privacySectionAds;

  /// Ads section text, free user.
  ///
  /// In en, this message translates to:
  /// **'The free app shows a banner ad at the bottom of the Apps and Settings screens only.'**
  String get privacyAdsInfo;

  /// Ads section text, Premium user.
  ///
  /// In en, this message translates to:
  /// **'You have Premium, so the app shows no ads.'**
  String get privacyAdsPremium;

  /// Row → consent options form.
  ///
  /// In en, this message translates to:
  /// **'Ad privacy choices'**
  String get privacyAdChoices;

  /// Row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose how ads are picked for you.'**
  String get privacyAdChoicesSubtitle;

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open ad privacy choices. Check your internet connection and try again.'**
  String get privacyAdChoicesFailed;

  /// Row → paywall (source privacy).
  ///
  /// In en, this message translates to:
  /// **'Remove ads with Premium'**
  String get privacyRemoveAds;

  /// IOS status row.
  ///
  /// In en, this message translates to:
  /// **'Ad tracking'**
  String get privacyTrackingTitle;

  /// Row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Allowed. You can change this in your iPhone\'s Settings.'**
  String get privacyTrackingAllowed;

  /// Row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Not allowed. You can change this in your iPhone\'s Settings.'**
  String get privacyTrackingDenied;

  /// Row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Not chosen yet. The app asks before it first shows an ad.'**
  String get privacyTrackingNotDetermined;

  /// Row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Turned off on this iPhone.'**
  String get privacyTrackingRestricted;

  /// Semantics hint of the tracking row.
  ///
  /// In en, this message translates to:
  /// **'Opens your phone\'s Settings'**
  String get privacyOpensSettings;

  /// Dialog title.
  ///
  /// In en, this message translates to:
  /// **'About ads in this app'**
  String get trackingPrepromptTitle;

  /// Dialog body.
  ///
  /// In en, this message translates to:
  /// **'The free app shows a small ad at the bottom of this screen. Next, your iPhone asks whether the app may use your activity in other apps to choose ads. You see the same number of ads whatever you choose, and the remote works the same.'**
  String get trackingPrepromptBody;

  /// The only action.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get trackingPrepromptContinue;

  /// Label band above the banner; its semantics label.
  ///
  /// In en, this message translates to:
  /// **'Advertisement'**
  String get adLabel;

  /// Headline.
  ///
  /// In en, this message translates to:
  /// **'Make the remote yours'**
  String get paywallHeadline;

  /// Text under the headline.
  ///
  /// In en, this message translates to:
  /// **'Premium removes ads, adds colour styles and supports the app\'s development.'**
  String get paywallSubhead;

  /// Benefit title.
  ///
  /// In en, this message translates to:
  /// **'No ads'**
  String get paywallBenefitNoAds;

  /// Benefit text.
  ///
  /// In en, this message translates to:
  /// **'No banner on the Apps and Settings screens.'**
  String get paywallBenefitNoAdsBody;

  /// Benefit title.
  ///
  /// In en, this message translates to:
  /// **'Colour styles'**
  String get paywallBenefitStyles;

  /// Benefit text.
  ///
  /// In en, this message translates to:
  /// **'Ocean, Ember and Midnight, in light and dark.'**
  String get paywallBenefitStylesBody;

  /// Honest note.
  ///
  /// In en, this message translates to:
  /// **'Everything else stays free: every TV, every remote control, app shortcuts, the keyboard and turning your TV on.'**
  String get paywallFreeForever;

  /// Radio group label.
  ///
  /// In en, this message translates to:
  /// **'Choose a plan'**
  String get paywallChoosePlan;

  /// Plan title.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get paywallPlanMonthly;

  /// Plan title.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get paywallPlanYearly;

  /// Plan title.
  ///
  /// In en, this message translates to:
  /// **'Lifetime'**
  String get paywallPlanLifetime;

  /// Plan price.
  ///
  /// In en, this message translates to:
  /// **'{price} per month'**
  String paywallPricePerMonth(String price);

  /// Plan price.
  ///
  /// In en, this message translates to:
  /// **'{price} per year'**
  String paywallPricePerYear(String price);

  /// Lifetime price.
  ///
  /// In en, this message translates to:
  /// **'{price}, one payment'**
  String paywallPriceOnce(String price);

  /// Monthly terms.
  ///
  /// In en, this message translates to:
  /// **'Renews every month until you cancel.'**
  String get paywallRenewsMonthly;

  /// Yearly terms.
  ///
  /// In en, this message translates to:
  /// **'Renews every year until you cancel.'**
  String get paywallRenewsYearly;

  /// Lifetime terms.
  ///
  /// In en, this message translates to:
  /// **'Pay once. No subscription.'**
  String get paywallLifetimeTerms;

  /// Badge on yearly.
  ///
  /// In en, this message translates to:
  /// **'Best value'**
  String get paywallBestValue;

  /// Badge text (`percent`: `int`).
  ///
  /// In en, this message translates to:
  /// **'Save {percent}%'**
  String paywallSavePercent(int percent);

  /// Purchase button.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get paywallContinue;

  /// Restore button.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get paywallRestore;

  /// Billing terms, Android.
  ///
  /// In en, this message translates to:
  /// **'Payment is charged to your Google Play account. Subscriptions renew automatically until you cancel them in Google Play, and you keep Premium until the end of the period you paid for.'**
  String get paywallTermsAndroid;

  /// Billing terms, iOS.
  ///
  /// In en, this message translates to:
  /// **'Payment is charged to your Apple ID. Subscriptions renew automatically unless you cancel at least 24 hours before the end of the current period. Manage or cancel them in your Apple ID settings.'**
  String get paywallTermsIos;

  /// Loading state.
  ///
  /// In en, this message translates to:
  /// **'Loading plans…'**
  String get paywallLoading;

  /// No offering.
  ///
  /// In en, this message translates to:
  /// **'Premium isn\'t available right now'**
  String get paywallUnavailableTitle;

  /// No offering (button reuses `commonRetry`).
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and try again.'**
  String get paywallUnavailableBody;

  /// In progress.
  ///
  /// In en, this message translates to:
  /// **'Confirming your purchase…'**
  String get paywallPurchasing;

  /// Shown while restoring earlier purchases.
  ///
  /// In en, this message translates to:
  /// **'Restoring your purchases…'**
  String get paywallRestoring;

  /// Snackbar after a purchase.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Premium. Thank you!'**
  String get paywallWelcome;

  /// Pending purchase.
  ///
  /// In en, this message translates to:
  /// **'Your purchase is waiting for approval. Premium starts as soon as it\'s complete.'**
  String get paywallPending;

  /// Unknown or store failure.
  ///
  /// In en, this message translates to:
  /// **'The purchase didn\'t go through. Try again.'**
  String get paywallFailed;

  /// Network failure.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the store. Check your internet connection and try again.'**
  String get paywallNetworkError;

  /// Purchases disabled.
  ///
  /// In en, this message translates to:
  /// **'Purchases aren\'t allowed on this phone.'**
  String get paywallNotAllowed;

  /// Already owned.
  ///
  /// In en, this message translates to:
  /// **'You already own Premium. Tap Restore purchases to get it back.'**
  String get paywallAlreadyOwned;

  /// Restore success.
  ///
  /// In en, this message translates to:
  /// **'Purchases restored. You have Premium.'**
  String get paywallRestored;

  /// Restore found nothing.
  ///
  /// In en, this message translates to:
  /// **'No purchases found for this account.'**
  String get paywallNothingToRestore;

  /// Restore failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t restore purchases. Try again.'**
  String get paywallRestoreFailed;

  /// Already-Premium state.
  ///
  /// In en, this message translates to:
  /// **'You have Premium'**
  String get paywallActiveTitle;

  /// Already-Premium state.
  ///
  /// In en, this message translates to:
  /// **'Thank you for supporting the app. There are no ads, and every colour style is yours.'**
  String get paywallActiveBody;

  /// Already Premium, lifetime.
  ///
  /// In en, this message translates to:
  /// **'Lifetime Premium: it never expires.'**
  String get paywallActiveLifetime;

  /// Opens the store's subscription page.
  ///
  /// In en, this message translates to:
  /// **'Manage subscription'**
  String get paywallManageSubscription;

  /// Group label.
  ///
  /// In en, this message translates to:
  /// **'Colour style'**
  String get appearanceStyle;

  /// Style name.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get appearanceStyleStandard;

  /// Style name.
  ///
  /// In en, this message translates to:
  /// **'Ocean'**
  String get appearanceStyleOcean;

  /// Style name.
  ///
  /// In en, this message translates to:
  /// **'Ember'**
  String get appearanceStyleEmber;

  /// Style name.
  ///
  /// In en, this message translates to:
  /// **'Midnight'**
  String get appearanceStyleMidnight;

  /// Subtitle of a locked style.
  ///
  /// In en, this message translates to:
  /// **'Included with Premium'**
  String get appearanceStyleLocked;

  /// Note while dynamic colour is on.
  ///
  /// In en, this message translates to:
  /// **'Colours from wallpaper are on, so colour styles don\'t show.'**
  String get appearanceStyleWallpaperOn;

  /// Blocking screen title.
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get updateRequiredTitle;

  /// Blocking screen text.
  ///
  /// In en, this message translates to:
  /// **'This version of the app is too old to keep working reliably. Update to the latest version to continue.'**
  String get updateRequiredBody;

  /// Opens the store listing.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateRequiredAction;

  /// Snackbar when the link fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the store. Update the app from your phone\'s app store.'**
  String get updateRequiredFailed;

  /// Spoken label of a progress spinner that has no other label.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loadingLabel;

  /// Tooltip and spoken label of the Edit apps overflow menu button.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get manageAppsMoreOptions;

  /// Announced to screen readers after an app is reordered in Edit apps (`app`: app name; `position`, `count`: `int`).
  ///
  /// In en, this message translates to:
  /// **'{app} moved to position {position} of {count}'**
  String manageAppsMoved(String app, int position, int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
