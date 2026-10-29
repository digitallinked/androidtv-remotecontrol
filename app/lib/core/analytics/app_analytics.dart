import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/analytics/analytics_events.dart';
import 'package:tv_remote/core/analytics/analytics_guard.dart';
import 'package:tv_remote/core/analytics/analytics_sink.dart';
import 'package:tv_remote/core/analytics/firebase_analytics_sink.dart';
import 'package:tv_remote/core/firebase/firebase_bootstrap.dart';
import 'package:tv_remote/core/privacy/privacy_choices.dart';
import 'package:tv_remote/features/apps/data/catalogue_repository.dart';

export 'package:tv_remote/core/analytics/analytics_guard.dart'
    show AnalyticsPolicyError;
export 'package:tv_remote/core/analytics/analytics_sink.dart';

part 'app_analytics.g.dart';

/// How many events wait for the privacy decision (Ruling P6-R4). When more
/// arrive, the oldest are forgotten.
const int analyticsBufferSize = 50;

/// Where analytics goes: Firebase when it is running, otherwise nowhere.
/// Tests override it with a recording fake.
@Riverpod(keepAlive: true)
AnalyticsSink analyticsSink(Ref ref) =>
    ref.watch(firebaseStatusProvider) == FirebaseStatus.ready
    ? const FirebaseAnalyticsSink()
    : const NoopAnalyticsSink();

/// Whether a guard violation throws (a debug build) instead of dropping the
/// event (release). A seam so tests can act as either.
@Riverpod(keepAlive: true)
bool analyticsDebugBuild(Ref ref) => kDebugMode;

/// An event or a screen view that waits for the privacy decision.
class _Pending {
  _Pending.event(AnalyticsEvent this.event) : screen = null;
  _Pending.screen(String this.screen) : event = null;

  final AnalyticsEvent? event;
  final String? screen;
}

/// The one door analytics goes through.
///
/// 1. The guard checks every event and screen name against the catalogue
///    (Ruling P6-R6): a debug build throws [AnalyticsPolicyError], a release
///    build drops the event.
/// 2. The privacy gate (Ruling P6-R4): sharing allowed sends it, undecided
///    keeps it in a buffer of the latest [analyticsBufferSize], denied drops
///    it.
/// 3. The sink gets the native on/off switch on every change of the choice.
///    When sharing turns out allowed the buffer is sent in order; when it
///    turns out denied the buffer is emptied.
///
/// A failing sink is never visible to callers. The app keeps this provider
/// listened to (through `analyticsHooksProvider`): Riverpod pauses a provider
/// nothing listens to, and its listener to the choice would stop.
@Riverpod(keepAlive: true)
class AppAnalytics extends _$AppAnalytics {
  final Queue<_Pending> _buffer = Queue<_Pending>();
  AnalyticsSink _sink = const NoopAnalyticsSink();
  bool _debugBuild = false;
  bool? _collecting;

  /// The collection switch on its way to the sink, or `null` when none is.
  /// Sends wait for it, so no event reaches the platform before collection
  /// is on.
  Future<void>? _switching;

  @override
  void build() {
    _sink = ref.watch(analyticsSinkProvider);
    _debugBuild = ref.watch(analyticsDebugBuildProvider);
    _buffer.clear();
    _collecting = null;
    _switching = null;
    ref.listen<PrivacyChoices>(
      privacyChoicesProvider,
      (previous, next) => _apply(next),
      fireImmediately: true,
    );
  }

  /// Logs [event], unless the guard or the user's choice stops it.
  void log(AnalyticsEvent event) {
    final packages = event.name == 'app_launch'
        ? _cataloguePackages()
        : const <String>{};
    final problems = analyticsViolations(
      event.name,
      event.params,
      cataloguePackages: packages,
    );
    if (!_accepts(problems, event.name)) return;
    _route(_Pending.event(event));
  }

  /// Logs a screen view for the route [routeName] (never a path).
  void screen(String routeName) {
    // The name is not repeated: a path could hold a TV's name.
    if (!_accepts(analyticsScreenViolations(routeName), 'screen_view')) {
      return;
    }
    _route(_Pending.screen(routeName));
  }

  Set<String> _cataloguePackages() {
    final catalogue = ref.read(catalogueProvider).value;
    return {
      if (catalogue != null)
        for (final app in catalogue.apps) app.package,
    };
  }

  bool _accepts(List<String> problems, String what) {
    if (problems.isEmpty) return true;
    if (_debugBuild) {
      throw AnalyticsPolicyError('$what: ${problems.join('; ')}');
    }
    if (kDebugMode) debugPrint('Analytics event dropped: $what');
    return false;
  }

  void _route(_Pending pending) {
    final choices = ref.read(privacyChoicesProvider);
    if (!choices.usageDecided) {
      _buffer.add(pending);
      while (_buffer.length > analyticsBufferSize) {
        _buffer.removeFirst();
      }
    } else if (choices.shareUsage) {
      _send(pending);
    }
  }

  void _apply(PrivacyChoices choices) {
    if (choices.shareUsage != _collecting) {
      _collecting = choices.shareUsage;
      final sink = _sink;
      final enabled = choices.shareUsage;
      final switching = _guarded(() => sink.setCollectionEnabled(enabled));
      _switching = switching;
      unawaited(
        switching.whenComplete(() {
          if (identical(_switching, switching)) _switching = null;
        }),
      );
    }
    if (!choices.usageDecided) return;
    if (choices.shareUsage) {
      while (_buffer.isNotEmpty) {
        _send(_buffer.removeFirst());
      }
    } else {
      _buffer.clear();
    }
  }

  /// Sends [pending] now, or after the collection switch in progress.
  /// Callbacks on one future run in the order they were registered, so the
  /// order of events is kept.
  void _send(_Pending pending) {
    final switching = _switching;
    if (switching != null) {
      unawaited(switching.then((_) => _deliver(pending)));
    } else {
      _deliver(pending);
    }
  }

  void _deliver(_Pending pending) {
    final sink = _sink;
    final event = pending.event;
    if (event != null) {
      _fire(() => sink.logEvent(event.name, event.params));
    } else {
      _fire(() => sink.logScreenView(pending.screen!));
    }
  }

  /// Runs [call]; the returned future never completes with an error.
  Future<void> _guarded(Future<void> Function() call) async {
    try {
      await call();
    } on Object {
      // The real sink already catches everything; this is a second net.
    }
  }

  void _fire(Future<void> Function() call) {
    try {
      unawaited(call().catchError((Object _) {}));
    } on Object {
      // The real sink already catches everything; this is a second net.
    }
  }
}
