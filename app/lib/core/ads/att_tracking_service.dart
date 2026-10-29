import 'dart:async';
import 'dart:developer' as developer;

import 'package:app_tracking_transparency/app_tracking_transparency.dart'
    as att;
import 'package:tv_remote/core/ads/tracking_service.dart';

/// [TrackingService] backed by the `app_tracking_transparency` plugin.
///
/// This is the only file that imports `app_tracking_transparency`. Every
/// call catches everything, `MissingPluginException` included: an error
/// counts as "there is no question here".
class AttTrackingService implements TrackingService {
  /// Creates the service. It touches the platform only when a method is
  /// called.
  AttTrackingService();

  /// iOS shows no system question while a dialog is still animating away;
  /// the plugin's documentation asks for this pause after a custom dialog.
  static const _afterDialog = Duration(milliseconds: 200);

  static TrackingStatus _map(att.TrackingStatus status) => switch (status) {
    att.TrackingStatus.notDetermined => TrackingStatus.notDetermined,
    att.TrackingStatus.restricted => TrackingStatus.restricted,
    att.TrackingStatus.denied => TrackingStatus.denied,
    att.TrackingStatus.authorized => TrackingStatus.authorized,
    att.TrackingStatus.notSupported => TrackingStatus.notApplicable,
  };

  @override
  Future<TrackingStatus> status() async {
    try {
      return _map(
        await att.AppTrackingTransparency.trackingAuthorizationStatus,
      );
    } on Object catch (error) {
      developer.log('tracking status failed', name: 'ads', error: error);
      return TrackingStatus.notApplicable;
    }
  }

  @override
  Future<TrackingStatus> request() async {
    try {
      await Future<void>.delayed(_afterDialog);
      return _map(
        await att.AppTrackingTransparency.requestTrackingAuthorization(),
      );
    } on Object catch (error) {
      developer.log('tracking request failed', name: 'ads', error: error);
      return TrackingStatus.notApplicable;
    }
  }
}
