import 'dart:developer' as developer;

import 'package:in_app_review/in_app_review.dart';
import 'package:tv_remote/core/review/review_prompter.dart';

/// [ReviewRequester] over the `in_app_review` plugin: Google Play's In-App
/// Review on Android, `SKStoreReviewController` on iOS.
///
/// Every error is caught, a missing plugin included: an unavailable API and a
/// failed request both answer `false`.
class InAppReviewRequester implements ReviewRequester {
  @override
  Future<bool> isAvailable() async {
    try {
      return await InAppReview.instance.isAvailable();
    } on Object catch (error) {
      developer.log('review API unavailable', name: 'review', error: error);
      return false;
    }
  }

  @override
  Future<bool> request() async {
    try {
      await InAppReview.instance.requestReview();
      return true;
    } on Object catch (error) {
      // On Android the plugin asks Play for a second review flow inside
      // `requestReview`; when that fails it answers "In-App Review API
      // unavailable". Nothing was shown, so the request didn't happen.
      developer.log('review request failed', name: 'review', error: error);
      return false;
    }
  }
}
