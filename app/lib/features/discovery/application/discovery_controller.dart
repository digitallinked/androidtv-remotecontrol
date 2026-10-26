import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/foundation.dart' show immutable, listEquals;
import 'package:riverpod_annotation/riverpod_annotation.dart';
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
      if (ref.mounted) state = current();
    }

    final subscription = discovery.watch().listen(
      (found) {
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
