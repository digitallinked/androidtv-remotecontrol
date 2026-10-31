import 'dart:io';
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

  test('phase_6_strings_load', () async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    expect(l.paywallPricePerMonth('RM 9.90'), 'RM 9.90 per month');
    expect(l.paywallSavePercent(40), 'Save 40%');
    expect(l.faqPrivacyA, contains('Privacy choices'));
    expect(l.pageTitlePrivacyChoices, 'Privacy choices');
  });

  test('phase_7_strings_load', () async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    expect(l.onboardingProgress(2, 3), 'Card 2 of 3');
    expect(l.onboardingContinue, 'Continue');
  });

  test('phase_8_strings_load', () async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    expect(
      l.manageAppsMoved('Netflix', 2, 5),
      'Netflix moved to position 2 of 5',
    );
    expect(l.loadingLabel, 'Loading…');
    expect(l.manageAppsMoreOptions, 'More options');
  });

  test('arb_has_no_lone_carriage_returns', () {
    // A lone CR survives gen-l10n and the format check, and joins two lines
    // into one for tools that only split on LF.
    final bytes = File('lib/app/l10n/app_en.arb').readAsBytesSync();
    final lone = <int>[
      for (var i = 0; i < bytes.length; i++)
        if (bytes[i] == 0x0D && (i + 1 >= bytes.length || bytes[i + 1] != 0x0A))
          i,
    ];
    expect(lone, isEmpty, reason: 'byte offsets of lone CRs');
  });
}
