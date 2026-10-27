import 'package:tv_remote/core/review/review_prompter.dart';

/// A [ReviewRequester] that answers [available] and records each request.
class FakeReviewRequester implements ReviewRequester {
  /// Creates a requester; the store's review API is [available].
  FakeReviewRequester({this.available = true});

  /// What [isAvailable] answers.
  bool available;

  /// How often [isAvailable] was asked.
  int availabilityChecks = 0;

  /// How often [request] was called.
  int requests = 0;

  @override
  Future<bool> isAvailable() async {
    availabilityChecks++;
    return available;
  }

  @override
  Future<void> request() async => requests++;
}
