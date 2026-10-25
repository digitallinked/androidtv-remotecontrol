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
  String get statusNeedsPairing => 'Pair again';

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
  String get routeNotFoundAction => 'Back to TVs';
}
