import 'package:tv_remote/core/ads/tracking_service.dart';

/// A [TrackingService] that answers from [current] and records the system
/// prompts it was asked for.
class FakeTrackingService implements TrackingService {
  /// Creates a fake whose status is [current].
  FakeTrackingService({
    this.current = TrackingStatus.notApplicable,
    this.answer = TrackingStatus.authorized,
  });

  /// What [status] answers.
  TrackingStatus current;

  /// What the user answers when [request] shows the system prompt.
  TrackingStatus answer;

  /// How many times [request] was called.
  int requests = 0;

  @override
  Future<TrackingStatus> status() async => current;

  @override
  Future<TrackingStatus> request() async {
    requests++;
    if (current == TrackingStatus.notDetermined) current = answer;
    return current;
  }
}
