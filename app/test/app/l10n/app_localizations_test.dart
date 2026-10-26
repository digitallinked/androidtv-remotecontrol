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

  test('phase_5_strings_load', () async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    expect(l.appsNoMatches('x'), 'No apps match "x".');
    expect(l.editDeviceRemoveTitle('TV'), 'Remove TV?');
    expect(l.aboutVersion('1.0.0', '1'), 'Version 1.0.0 (1)');
    expect(l.pageTitleDevices, 'Your TVs');
  });
}
