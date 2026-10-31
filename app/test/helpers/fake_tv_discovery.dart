import 'dart:async';

import 'package:atv_remote/atv_remote.dart';

/// A discovered TV for tests: [name] is both the service and the display
/// name.
DiscoveredTv tv(
  String name, {
  String host = '192.168.0.20',
  bool legacy = false,
}) => DiscoveredTv(
  serviceName: name,
  displayName: name,
  host: host,
  port: 6466,
  isLegacyService: legacy,
);

/// A [TvDiscovery] that tests drive by hand.
class FakeTvDiscovery implements TvDiscovery {
  late final StreamController<List<DiscoveredTv>> _controller =
      StreamController<List<DiscoveredTv>>.broadcast(
        onListen: () => onListen?.call(this),
      );

  /// Called when [watch]'s stream gets its first listener, so a test can
  /// emit what is "found" once someone is listening.
  void Function(FakeTvDiscovery discovery)? onListen;

  /// How many times [watch] was called.
  int watchCalls = 0;

  bool _stopped = false;

  /// Whether [stop] was called.
  bool get stopped => _stopped;

  /// Emits [tvs] to the listeners of [watch].
  void emit(List<DiscoveredTv> tvs) => _controller.add(tvs);

  /// Emits [error] to the listeners of [watch].
  void fail(Object error) => _controller.addError(error);

  @override
  Stream<List<DiscoveredTv>> watch() {
    watchCalls++;
    return _controller.stream;
  }

  /// When set, [stop] fails with it (after stopping), like a platform that
  /// refuses to stop a browse.
  Object? stopError;

  @override
  Future<void> stop() async {
    _stopped = true;
    await _controller.close();
    final error = stopError;
    // The test chose what to throw, an Error or not.
    // ignore: only_throw_errors
    if (error != null) throw error;
  }
}

/// Hands out [FakeTvDiscovery] instances, as a `TvDiscoveryFactory`.
class FakeTvDiscoveries {
  /// Every instance created so far, in order.
  final List<FakeTvDiscovery> created = [];

  /// Called with each new instance, so a test can script it.
  void Function(FakeTvDiscovery discovery)? onCreate;

  /// Creates and records a new [FakeTvDiscovery].
  TvDiscovery create() {
    final discovery = FakeTvDiscovery();
    created.add(discovery);
    onCreate?.call(discovery);
    return discovery;
  }
}
