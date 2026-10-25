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
}
