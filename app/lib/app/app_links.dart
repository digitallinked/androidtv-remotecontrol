import 'package:flutter/foundation.dart';
import 'package:tv_remote/app/flavor.dart';

/// Where the app sends people for legal pages and support.
abstract final class AppLinks {
  /// The privacy policy page.
  ///
  /// Value from `docs/release/placeholders.json` → `PRIVACY_POLICY_URL`;
  /// the release check refuses the placeholder.
  static final Uri privacyPolicy = Uri.parse(
    'https://remotely.newy.my/privacy',
  );

  /// The terms of use page.
  ///
  /// Value from `docs/release/placeholders.json` → `TERMS_URL`; the release
  /// check refuses the placeholder.
  static final Uri terms = Uri.parse('https://remotely.newy.my/terms');

  /// The address feedback emails go to.
  ///
  /// Value from `docs/release/placeholders.json` → `SUPPORT_EMAIL`.
  static const String supportEmail = 'support@newy.my';

  /// The App Store page of the app.
  ///
  /// Value from `docs/release/placeholders.json` → `APP_STORE_ID` (the
  /// digits after `id`); the release check refuses the placeholder.
  static final Uri appStoreListing = Uri.parse(
    'https://apps.apple.com/app/id0000000000',
  );

  /// The store page where [flavor] can be updated on [platform]: the Play
  /// Store page of its application id on Android, [appStoreListing] on iOS.
  static Uri storeListing(Flavor flavor, TargetPlatform platform) =>
      platform == TargetPlatform.iOS
      ? appStoreListing
      : Uri.parse(
          'https://play.google.com/store/apps/details'
          '?id=${flavor.applicationId}',
        );

  /// The store page where the user manages or cancels a subscription on
  /// [platform]: Google Play's subscription list for the application id of
  /// [flavor] on Android, the App Store's account page on iOS.
  static Uri manageSubscriptions(Flavor flavor, TargetPlatform platform) =>
      platform == TargetPlatform.iOS
      ? Uri.parse('https://apps.apple.com/account/subscriptions')
      : Uri.parse(
          'https://play.google.com/store/account/subscriptions'
          '?package=${flavor.applicationId}',
        );
}
