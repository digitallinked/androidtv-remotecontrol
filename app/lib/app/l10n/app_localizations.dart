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

  /// Headline of the first-run onboarding screen.
  ///
  /// In en, this message translates to:
  /// **'Control your TV from your phone'**
  String get onboardingTitle;

  /// Body text of the first-run onboarding screen.
  ///
  /// In en, this message translates to:
  /// **'Find your Android TV on this Wi-Fi network and pair it in a few seconds.'**
  String get onboardingBody;

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

  /// Title of the saved TVs screen.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
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
