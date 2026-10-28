import 'dart:async';

import 'package:tv_remote/core/review/review_prompter.dart';

/// A [ReviewRequester] that answers [available] and [requestSucceeds] and
/// records each call.
class FakeReviewRequester implements ReviewRequester {
  /// Creates a requester; the store's review API is [available] and a
  /// request succeeds when [requestSucceeds].
  FakeReviewRequester({this.available = true, this.requestSucceeds = true});

  /// What [isAvailable] answers.
  bool available;

  /// What [request] answers: `false` is a request the plugin reported as
  /// failed.
  bool requestSucceeds;

  /// When set, [isAvailable] waits for it before answering.
  Completer<void>? holdAvailability;

  /// How often [isAvailable] was asked.
  int availabilityChecks = 0;

  /// How often [request] was called.
  int requests = 0;

  @override
  Future<bool> isAvailable() async {
    availabilityChecks++;
    await holdAvailability?.future;
    return available;
  }

  @override
  Future<bool> request() async {
    requests++;
    return requestSucceeds;
  }
}
