import 'dart:developer' as developer;

import 'package:in_app_review/in_app_review.dart';
import 'package:tv_remote/core/review/review_prompter.dart';

/// [ReviewRequester] over the `in_app_review` plugin: Google Play's In-App
/// Review on Android, `SKStoreReviewController` on iOS.
///
/// Every error is caught, a missing plugin included: an unavailable API
/// answers `false`, and a failed request is only logged.
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
  Future<void> request() async {
    try {
      await InAppReview.instance.requestReview();
    } on Object catch (error) {
      developer.log('review request failed', name: 'review', error: error);
    }
  }
}
