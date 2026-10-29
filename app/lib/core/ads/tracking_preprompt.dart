import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/widgets/app_dialog.dart';
import 'package:tv_remote/core/ads/tracking_service.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';

part 'tracking_preprompt.g.dart';

/// The pre-prompt that is on screen or on its way, so two callers that ask
/// at once get one dialog and one system question.
class TrackingPreprompt {
  /// Creates an idle holder.
  TrackingPreprompt();

  /// The decision in progress, or `null` when none is.
  Future<void>? inFlight;
}

/// Holds the [TrackingPreprompt] of this launch.
@Riverpod(keepAlive: true)
TrackingPreprompt trackingPreprompt(Ref ref) => TrackingPreprompt();

/// Makes sure the user has been asked about ad tracking, right before the
/// first banner loads (Ruling P6-R8).
///
/// It returns at once unless the platform is iOS and the system question is
/// still unanswered (`notDetermined`). The first time, it shows a themed
/// dialog with one action, "Continue", that can't be left by the barrier or
/// Back, then asks the system. The pre-prompt is shown at most once. If iOS
/// didn't show its question (it shows nothing while the app isn't active),
/// the next banner visit asks the system again directly, with no second
/// pre-prompt; iOS itself never shows its question twice. Calls made while
/// one is running share it. It never throws.
Future<void> ensureTrackingDecided(BuildContext context, WidgetRef ref) {
  final holder = ref.read(trackingPrepromptProvider);
  final running = holder.inFlight;
  if (running != null) return running;
  final next = _decide(context, ref).whenComplete(() => holder.inFlight = null);
  return holder.inFlight = next;
}

Future<void> _decide(BuildContext context, WidgetRef ref) async {
  try {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    final store = ref.read(settingsStoreProvider);
    final tracking = ref.read(trackingServiceProvider);
    if (await tracking.status() != TrackingStatus.notDetermined) return;
    // The pre-prompt was shown, but iOS never showed its question: ask the
    // system again, without a second pre-prompt.
    if (store.trackingPrepromptShown) {
      await tracking.request();
      return;
    }
    if (!context.mounted) return;

    final l10n = AppLocalizations.of(context);
    await showAppDialog<void>(
      context: context,
      title: l10n.trackingPrepromptTitle,
      message: l10n.trackingPrepromptBody,
      actions: [
        AppDialogAction(
          label: l10n.trackingPrepromptContinue,
          value: null,
          isPrimary: true,
        ),
      ],
      barrierDismissible: false,
    );
    await store.setTrackingPrepromptShown(true);
    await tracking.request();
  } on Object catch (error) {
    developer.log('tracking pre-prompt failed', name: 'ads', error: error);
  }
}
