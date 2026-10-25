import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';

void main() {
  test('english_strings_load', () async {
    expect(AppLocalizations.supportedLocales, contains(const Locale('en')));
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    expect(l.statusReconnecting, 'Reconnecting…');
    expect(l.statusSemantics('Offline'), 'Connection: Offline');
  });
}
