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

  /// Connection status pill: the TV no longer accepts this phone and it must be paired again.
  ///
  /// In en, this message translates to:
  /// **'Pair again'**
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
