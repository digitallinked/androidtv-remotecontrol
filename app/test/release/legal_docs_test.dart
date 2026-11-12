import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';


/// The text of `docs/release/legal/<name>`; the tests run from `app/`.
String legalDoc(String name) =>
    File('../docs/release/legal/$name').readAsStringSync();

/// The English value of the ARB string [key].
String english(String key) {
  final arb =
      jsonDecode(File('lib/app/l10n/app_en.arb').readAsStringSync())
          as Map<String, Object?>;
  return arb[key]! as String;
}

void main() {
  final privacy = legalDoc('privacy-policy.md');
  final terms = legalDoc('terms.md');

  // The owner approved the texts on 2026-11-12: they are hosted as they are,
  // so no draft line, owner note or owner checklist may be left in them, and
  // each has a Malay version with the same placeholders (PDPA section 7).
  test('legal_docs_are_final_with_no_draft_or_owner_notes', () {
    for (final name in const [
      'privacy-policy.md',
      'terms.md',
      'privacy-policy.ms.md',
      'terms.ms.md',
    ]) {
      final doc = legalDoc(name);
      expect(const LineSplitter().convert(doc).first, startsWith('# '),
          reason: name);
      expect(doc, isNot(contains('DRAFT')), reason: name);
      expect(doc.toLowerCase(), isNot(contains('owner to confirm')),
          reason: name);
    }
  });

  test('malay_legal_docs_carry_the_same_placeholders', () {
    Set<String> tokens(String doc) =>
        RegExp(r'\{\{([A-Z_]+)\}\}').allMatches(doc).map((m) => m[1]!).toSet();
    expect(tokens(legalDoc('privacy-policy.ms.md')), tokens(privacy));
    expect(tokens(legalDoc('terms.ms.md')), tokens(terms));
  });

  test('privacy_policy_covers_pdpa_gdpr_and_us_state_laws', () {
    for (final text in const [
      'Personal Data Protection Act 2010',
      'GDPR',
      'United States',
      '21 days',
      'How long information is kept',
    ]) {
      expect(privacy, contains(text));
    }
  });

  test('privacy_policy_names_every_service_the_app_uses', () {
    for (final name in const [
      'Firebase Analytics',
      'Firebase Crashlytics',
      'Firebase Remote Config',
      'Firebase Installation',
      'AdMob',
      'User Messaging Platform',
      'App Tracking Transparency',
      'RevenueCat',
      'Google Play',
      'App Store',
    ]) {
      expect(privacy, contains(name));
    }
  });

  test('privacy_policy_says_what_never_leaves_the_phone', () {
    final lower = privacy.toLowerCase();
    for (final fact in const [
      'tv name',
      'network address',
      'mac address',
      'pairing certificate',
      'backup',
      'device transfer',
    ]) {
      expect(lower, contains(fact));
    }
  });

  test('privacy_policy_discloses_full_screen_ads_and_the_kept_certificate', () {
    // Ruling P9-C8: Remote Config can turn interstitials on, and the iOS
    // keychain can outlive the app.
    expect(
      privacy,
      contains('occasional full-screen ad when you leave Settings'),
    );
    expect(privacy, contains('switch features on or off'));
    expect(
      privacy,
      contains(
        "On iPhone, iOS may keep the app's pairing certificate in the "
        'keychain after you delete the app; the app replaces it with a new '
        'one when you install it again.',
      ),
    );
    expect(privacy, isNot(contains('to delete everything it keeps')));
    expect(privacy, isNot(contains('Settings screens only')));
  });

  test('privacy_policy_matches_the_in_app_controls', () {
    for (final key in const [
      'pageTitlePrivacyChoices',
      'privacyUsageTitle',
      'privacyCrashTitle',
      'privacyAdChoices',
      'privacyTrackingTitle',
    ]) {
      expect(privacy, contains(english(key)), reason: key);
    }
  });

  test('terms_cover_premium_renewal_and_the_trademark_notice', () {
    for (final text in [
      'renew',
      'cancel',
      'refund',
      'Lifetime',
      'Licensed Application End User License Agreement',
      english('aboutTrademark'),
    ]) {
      expect(terms, contains(text));
    }
  });

  test('legal_docs_never_name_the_competitor', () {
    for (final doc in [privacy, terms]) {
      final lower = doc.toLowerCase();
      expect(lower, isNot(contains('remote atv')));
      expect(lower, isNot(contains('simha')));
    }
  });
}
