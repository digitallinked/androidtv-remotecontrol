import 'dart:async';
import 'dart:developer' as developer;

import 'package:atv_remote/atv_remote.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/ads/consent_controller.dart';
import 'package:tv_remote/core/analytics/analytics_events.dart';
import 'package:tv_remote/core/analytics/app_analytics.dart';
import 'package:tv_remote/core/config/app_config.dart';
import 'package:tv_remote/core/crash/crash_reporter.dart';
import 'package:tv_remote/core/crash/error_handlers.dart';
import 'package:tv_remote/core/review/in_app_review_requester.dart';
import 'package:tv_remote/core/session/connection_trouble.dart';
import 'package:tv_remote/core/session/lifecycle_observer.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/session/session_signals.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';

part 'review_prompter.g.dart';

/// The store's own review prompt (Google Play In-App Review, Apple's
/// `SKStoreReviewController`).
///
/// The store decides whether the prompt actually appears; the app only asks.
abstract interface class ReviewRequester {
  /// Whether the review API can be asked on this phone right now.
  Future<bool> isAvailable();

  /// Asks the store to show its review prompt. Answers whether the request
  /// went through: `false` means it failed and nothing was shown. `true`
  /// means the store had its chance; whether a prompt actually appeared is
  /// the store's decision and is never reported back.
  Future<bool> request();
}

/// The review API: the `in_app_review` plugin.
@Riverpod(keepAlive: true)
ReviewRequester reviewRequester(Ref ref) => InAppReviewRequester();

/// How long after connection trouble (see [ConnectionTrouble]) the review
/// prompt is not asked.
const Duration reviewQuietAfterTrouble = Duration(seconds: 60);

/// The launch on which the review prompt may first be asked.
const int reviewFirstLaunch = 2;

/// The key press count is written to storage every this many presses (and
/// when the app goes to the background).
const int reviewPressSaveInterval = 10;

/// The statuses that mean the connection is in trouble: lost, refused or
/// unreachable.
const Set<ConnectionStatus> _troubled = {
  ConnectionStatus.reconnecting,
  ConnectionStatus.needsPairing,
  ConnectionStatus.offline,
};

/// Asks the store for its review prompt once the remote has proven itself
/// (Ruling P6-R13).
///
/// The prompt is asked at most once per install, when all of these hold:
/// - the key presses counted so far reach `review_prompt_min_key_presses`
///   (Remote Config, 150 by default);
/// - this is at least the second launch;
/// - the session is not the demo;
/// - a session has just started: the TV became connected from not being
///   connected, and not as the recovery from a lost connection; and no
///   connection trouble (a loss, a failed connect or a "Not connected"
///   notice) happened in the last 60 s;
/// - the ad consent step of this launch has finished without showing its
///   form (Ruling P6-C11): two system dialogs never stack. While the step is
///   still running the prompt waits for it, and asks if the TV is still
///   connected when it ends. After a shown form, never this launch.
///
/// The press count lives in memory and is written every 10 presses and when
/// the app goes to the background, so a key press never waits for storage.
/// When the review API is unavailable, or the request fails (Ruling P6-C12),
/// nothing is marked and the next clean start tries again. Nothing here
/// throws.
///
/// The app starts this at launch and keeps it listened to (`App` watches
/// it): Riverpod may pause the listeners inside a provider nothing listens
/// to.
@Riverpod(keepAlive: true)
class ReviewPrompter extends _$ReviewPrompter {
  late SettingsStore _store;
  int _presses = 0;
  int _saved = 0;
  ConnectionStatus? _last;
  bool _asking = false;
  bool _awaitingConsent = false;

  @override
  void build() {
    _store = ref.watch(settingsStoreProvider);
    final signals = ref.watch(sessionSignalsProvider);
    _presses = _saved = _store.reviewKeyPresses;
    _last = null;
    _asking = false;
    _awaitingConsent = false;

    final paused = signals.visibility.listen((visibility) {
      if (visibility == AppVisibility.background) unawaited(_save());
    });
    ref
      ..onDispose(() {
        unawaited(paused.cancel().catchError((Object _) {}));
        unawaited(_save());
      })
      // A status of the session that is going away says nothing about the
      // new one, so a TV switch starts from a clean slate.
      ..listen(remoteSessionProvider, (_, _) => _last = null)
      ..listen(connectionStateProvider, (_, next) {
        final status = next.value?.status;
        if (next.isLoading || status == null) return;
        final was = _last;
        _last = status;
        if (status == ConnectionStatus.connected &&
            was != ConnectionStatus.connected &&
            !_troubled.contains(was)) {
          unawaited(_maybePrompt());
        }
      })
      // Started with this, so it hears trouble from launch on.
      ..listen(connectionTroubleProvider, (_, _) {})
      // A prompt held back by the consent step gets its chance when the step
      // ends, if the session it was for is still connected.
      ..listen(consentControllerProvider, (_, next) {
        if (!_awaitingConsent || !next.gathered) return;
        _awaitingConsent = false;
        if (!next.formShown && _last == ConnectionStatus.connected) {
          unawaited(_maybePrompt());
        }
      });
  }

  bool _isDemo() => ref.read(remoteSessionProvider).value?.isDemo ?? false;

  /// Counts one key press sent to the TV. Presses in the demo don't count,
  /// and none are counted once the prompt has been asked.
  void countPress() {
    try {
      if (_isDemo()) return;
      if (_store.reviewPromptShown) return;
      _presses++;
      if (_presses % reviewPressSaveInterval == 0) unawaited(_save());
    } on Object catch (error) {
      developer.log('review press not counted', name: 'review', error: error);
    }
  }

  /// Writes the count if it changed since the last write. Never throws, and
  /// works after dispose (it uses no `ref`).
  Future<void> _save() async {
    final value = _presses;
    if (value == _saved) return;
    try {
      await _store.setReviewKeyPresses(value);
      _saved = value;
    } on Object catch (error) {
      developer.log('review count not saved', name: 'review', error: error);
    }
  }

  /// Asks for the review if Ruling P6-R13 allows it now. Never throws.
  Future<void> _maybePrompt() async {
    if (_asking) return;
    try {
      final store = _store;
      if (store.reviewPromptShown || _isDemo()) return;
      if (store.launchCount < reviewFirstLaunch) return;
      // Never on a launch whose consent form is pending or was shown. A
      // pending step is waited for (see the listener in `build`).
      final consent = ref.read(consentControllerProvider);
      if (!consent.gathered) {
        _awaitingConsent = true;
        return;
      }
      if (consent.formShown) return;
      final threshold = ref.read(appConfigProvider).reviewPromptMinKeyPresses;
      if (_presses < threshold) return;
      if (ref
          .read(connectionTroubleProvider.notifier)
          .troubleWithin(reviewQuietAfterTrouble)) {
        return;
      }

      final requester = ref.read(reviewRequesterProvider);
      final analytics = ref.read(appAnalyticsProvider.notifier);
      final reporter = ref.read(crashReporterProvider);
      _asking = true;
      try {
        if (!await requester.isAvailable() || !ref.mounted) return;
        // A failed request showed nothing: nothing is marked, and the next
        // clean start may ask again (Ruling P6-C12).
        if (!await requester.request()) return;
        try {
          // Asked: never again, even if this container is going away.
          await store.setReviewPromptShown(true);
        } on Object catch (error, stack) {
          // The next clean start would ask again; the store's own quota
          // limits that. Worth knowing about, so it is reported.
          await safeRecordError(
            reporter,
            error,
            stack,
            reason: 'review prompt flag',
          );
        }
        if (!ref.mounted) return;
        analytics.log(const AnalyticsEvent.reviewPromptShown());
      } finally {
        _asking = false;
      }
    } on Object catch (error) {
      developer.log('review prompt failed', name: 'review', error: error);
    }
  }
}
