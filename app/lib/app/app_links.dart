import 'package:flutter/foundation.dart';
import 'package:tv_remote/app/flavor.dart';

/// Where the app sends people for legal pages and support.
abstract final class AppLinks {
  /// The privacy policy page.
  ///
  /// PLACEHOLDER until the owner provides the real address (Phase 9 replaces
  /// it).
  static final Uri privacyPolicy = Uri.parse('https://example.com/privacy');

  /// The terms of use page.
  ///
  /// PLACEHOLDER until the owner provides the real address (Phase 9 replaces
  /// it).
  static final Uri terms = Uri.parse('https://example.com/terms');

  /// The address feedback emails go to.
  ///
  /// PLACEHOLDER until the owner provides the real address (Phase 9 replaces
  /// it).
  static const String supportEmail = 'support@example.com';

  /// The App Store page of the app.
  ///
  /// PLACEHOLDER until the App Store record exists (Phase 9).
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
