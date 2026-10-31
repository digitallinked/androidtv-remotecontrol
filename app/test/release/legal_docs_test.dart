import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The first line of both legal drafts (Ruling P9-R12).
const String draftLine =
    '> DRAFT — not legal advice. The owner (and, if they choose, a lawyer) '
    'reviews this before it is hosted.';

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

  test('legal_docs_are_marked_draft_until_the_owner_reviews_them', () {
    for (final doc in [privacy, terms]) {
      expect(const LineSplitter().convert(doc).first, draftLine);
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
