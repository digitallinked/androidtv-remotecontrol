import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/foundation.dart' show immutable, listEquals;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/analytics/analytics_events.dart';
import 'package:tv_remote/core/analytics/app_analytics.dart';
import 'package:tv_remote/core/crash/crash_collection.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/session/session_target.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/discovery/data/discovery_providers.dart';

part 'discovery_controller.g.dart';

/// How long the search may find nothing before the screen offers
/// troubleshooting.
const discoveryEmptyTimeout = Duration(seconds: 10);

/// What the discovery screen shows.
@immutable
class DiscoveryState {
  /// Creates a state.
  const DiscoveryState({
    required this.tvs,
    required this.showTroubleshooting,
    required this.failed,
  });

  /// The TVs found so far, sorted by name.
  final List<DiscoveredTv> tvs;

  /// Whether to offer help: the search found nothing within
  /// [discoveryEmptyTimeout], or it failed.
  final bool showTroubleshooting;

  /// Whether the search itself failed (for example, Wi-Fi is off or the
  /// platform refused to browse).
  final bool failed;

  @override
  bool operator ==(Object other) =>
      other is DiscoveryState &&
      other.showTroubleshooting == showTroubleshooting &&
      other.failed == failed &&
      listEquals(other.tvs, tvs);

  @override
  int get hashCode =>
      Object.hash(showTroubleshooting, failed, Object.hashAll(tvs));

  @override
  String toString() =>
      'DiscoveryState(tvs: ${tvs.length}, '
      'showTroubleshooting: $showTroubleshooting, failed: $failed)';
}

/// Searches the network for TVs while the discovery screen is open.
///
/// The search stops when the screen goes away.
@riverpod
class DiscoveryController extends _$DiscoveryController {
  // Kept across a rescan: the event says "a TV was found", once.
  bool _foundLogged = false;

  @override
  DiscoveryState build() {
    final discovery = ref.watch(tvDiscoveryFactoryProvider)();
    var tvs = const <DiscoveredTv>[];
    var timedOut = false;
    var failed = false;

    DiscoveryState current() => DiscoveryState(
      tvs: tvs,
      showTroubleshooting: (timedOut && tvs.isEmpty) || failed,
      failed: failed,
    );

    void publish() {
      if (!ref.mounted) return;
      if (!_foundLogged && tvs.isNotEmpty) {
        _foundLogged = true;
        ref
            .read(appAnalyticsProvider.notifier)
            .log(AnalyticsEvent.tvDiscovered(tvs.length));
      }
      state = current();
    }

    final subscription = discovery.watch().listen(
      (found) {
        // Names of TVs nobody saved must not reach a crash report either
        // (Ruling P8-R11). Crash collection runs only once Firebase is ready;
        // without it there is nothing to scrub, so it isn't started here.
        if (ref.mounted && ref.exists(crashCollectionProvider)) {
          ref.read(crashCollectionProvider.notifier).addDiscoveredTerms(found);
        }
        tvs = _sorted(found);
        publish();
      },
      onError: (Object error) {
        failed = true;
        publish();
      },
    );
    final timer = Timer(discoveryEmptyTimeout, () {
      timedOut = true;
      publish();
    });

    ref.onDispose(() {
      timer.cancel();
      unawaited(subscription.cancel());
      unawaited(discovery.stop());
    });
    return current();
  }

  /// Stops the search and starts a new one.
  void rescan() => ref.invalidateSelf();

  /// Moves the saved TV [manualServiceName] (added by IP address) to [tv],
  /// its mDNS entry, in one transaction (decision #33), and moves the remote
  /// with it. Returns whether it merged; storage errors propagate.
  ///
  /// [opening] is asked once the merge is done: whether the user is still
  /// opening this TV. Then the merged TV becomes the active one. Otherwise
  /// (the user left meanwhile, and this controller may be gone) only a
  /// session that still points at the deleted row moves (Ruling P8-R10):
  /// the active target names it, so it moves to the merged name; or there
  /// is no target and the default session was built on it, so that session
  /// is rebuilt on the merged row. Nobody else is pulled onto this TV.
  Future<bool> adoptManualDevice({
    required String manualServiceName,
    required DiscoveredTv tv,
    required bool Function() opening,
  }) async {
    // Everything is taken before the first await: the user may leave
    // discovery meanwhile, which disposes this controller.
    final container = ref.container;
    final devices = ref.read(deviceRepositoryProvider);
    final adopted = await devices.adoptManualDevice(
      manualServiceName: manualServiceName,
      tv: tv,
    );
    if (!adopted) return false;

    final target = container.read(activeTargetProvider);
    if (opening() || target == DeviceTarget(manualServiceName)) {
      container
          .read(activeTargetProvider.notifier)
          .activateDevice(tv.serviceName);
    } else if (target == null &&
        container.exists(remoteSessionProvider) &&
        container
                .read(remoteSessionProvider)
                .value
                ?.pairingTarget
                ?.serviceName ==
            manualServiceName) {
      container.invalidate(remoteSessionProvider);
    }
    return true;
  }

  static List<DiscoveredTv> _sorted(List<DiscoveredTv> tvs) {
    final sorted = [...tvs]
      ..sort((a, b) {
        final byName = a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        );
        return byName != 0 ? byName : a.serviceName.compareTo(b.serviceName);
      });
    return sorted;
  }
}
