import 'dart:math' as math;

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/analytics/analytics_events.dart';
import 'package:tv_remote/core/analytics/app_analytics.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/settings_controller.dart';
import 'package:tv_remote/core/storage/settings_store.dart'
    show NavigationStyle, QuickAccessRow;
import 'package:tv_remote/features/apps/data/catalogue_repository.dart';

part 'analytics_hooks.g.dart';

/// The share of key presses that are logged.
const double keyPressSampleRate = 0.1;

/// Chooses which key presses are logged: a value from 0 up to (not including)
/// 1; a press is logged when it is below [keyPressSampleRate]. Tests replace
/// it with a fixed sequence.
@Riverpod(keepAlive: true)
double Function() analyticsSampler(Ref ref) => math.Random().nextDouble;

/// What the remote reports to analytics, from `remoteActionListenerProvider`.
///
/// Typed text is not here on purpose: not even its length is logged.
class AnalyticsHooks {
  /// Creates the hooks; the provider builds them.
  AnalyticsHooks({
    required this._keySent,
    required this._appLaunched,
  });

  final void Function(int keyCode) _keySent;
  final void Function(String package) _appLaunched;

  /// A key was sent to the TV; about one in ten is logged.
  void keySent(int keyCode) => _keySent(keyCode);

  /// An app launch link was sent; the package is logged only when the
  /// catalogue knows it.
  void appLaunched(String package) => _appLaunched(package);
}

/// Connects analytics to the parts of the app that happen on their own: the
/// connection (`connect_success`, `connect_lost`) and the layout settings
/// (`layout_change`), and offers the remote's hooks.
///
/// The app reads it once at start. Its listeners need it to stay listened to,
/// which `App` does.
@Riverpod(keepAlive: true)
AnalyticsHooks analyticsHooks(Ref ref) {
  // Watching the state builds analytics now and keeps it listened to.
  ref.watch(appAnalyticsProvider);
  final analytics = ref.watch(appAnalyticsProvider.notifier);
  final sampler = ref.watch(analyticsSamplerProvider);

  bool isDemo() => ref.read(remoteSessionProvider).value?.isDemo ?? false;

  // A connection change of the session that is going away says nothing about
  // the new one, so a TV switch starts from a clean slate.
  ConnectionStatus? last;
  ref
    ..listen(remoteSessionProvider, (_, _) => last = null)
    ..listen(connectionStateProvider, (_, next) {
      final state = next.value;
      if (next.isLoading || state == null) return;
      final was = last;
      last = state.status;
      if (isDemo()) return;
      final status = state.status;
      if (status == ConnectionStatus.connected) {
        if (was != ConnectionStatus.connected) {
          analytics.log(const AnalyticsEvent.connectSuccess());
        }
      } else if (was == ConnectionStatus.connected &&
          status != ConnectionStatus.disconnected) {
        // `disconnected` is always the app closing the connection itself (the
        // background grace, a reconnect, a TV switch): not a loss. A real
        // loss goes through reconnecting, offline or needsPairing.
        analytics.log(AnalyticsEvent.connectLost(state.lastError));
      }
    })
    ..listen<(NavigationStyle, QuickAccessRow)>(
      settingsControllerProvider.select(
        (s) => (s.navigationStyle, s.quickAccessRow),
      ),
      (previous, next) {
        if (previous == null) return;
        if (previous.$1 != next.$1) {
          analytics.log(AnalyticsEvent.layoutChange(snakeCase(next.$1.name)));
        }
        if (previous.$2 != next.$2) {
          analytics.log(AnalyticsEvent.layoutChange(snakeCase(next.$2.name)));
        }
      },
    );

  return AnalyticsHooks(
    keySent: (keyCode) {
      if (isDemo() || sampler() >= keyPressSampleRate) return;
      analytics.log(AnalyticsEvent.keyPress(keyCode));
    },
    appLaunched: (package) {
      if (isDemo()) return;
      final catalogue = ref.read(catalogueProvider).value;
      final known =
          catalogue != null &&
          catalogue.apps.any((app) => app.package == package);
      analytics.log(AnalyticsEvent.appLaunch(known ? package : 'custom'));
    },
  );
}
