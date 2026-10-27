import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/ads/att_tracking_service.dart';

part 'tracking_service.g.dart';

/// The user's answer to iOS's "Allow tracking" question.
enum TrackingStatus {
  /// There is no such question here (Android, or an iOS before 14).
  notApplicable,

  /// The question has not been asked yet.
  notDetermined,

  /// The phone does not allow the question (for example parental controls).
  restricted,

  /// The user said no.
  denied,

  /// The user said yes.
  authorized,
}

/// App Tracking Transparency, behind our own interface.
abstract interface class TrackingService {
  /// The current answer, without asking.
  Future<TrackingStatus> status();

  /// Shows the system question when it hasn't been answered and returns the
  /// answer. Otherwise returns the existing answer.
  Future<TrackingStatus> request();
}

/// [TrackingService] for platforms without the question.
class NoTrackingService implements TrackingService {
  /// Creates the service.
  const NoTrackingService();

  @override
  Future<TrackingStatus> status() async => TrackingStatus.notApplicable;

  @override
  Future<TrackingStatus> request() async => TrackingStatus.notApplicable;
}

/// The app's [TrackingService]: App Tracking Transparency on iOS, nothing
/// elsewhere.
@Riverpod(keepAlive: true)
TrackingService trackingService(Ref ref) =>
    defaultTargetPlatform == TargetPlatform.iOS
    ? AttTrackingService()
    : const NoTrackingService();

/// The current tracking answer, for the Privacy choices page. It is asked
/// again each time the page watches it anew.
@riverpod
Future<TrackingStatus> trackingStatus(Ref ref) =>
    ref.watch(trackingServiceProvider).status();
