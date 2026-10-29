import 'package:tv_remote/core/config/app_config.dart';

/// A [RemoteConfigSource] that serves [values] once [activateCached] ran, and
/// records the calls it gets.
///
/// [fetchForNextLaunch] changes what the next launch would see ([fetched] is
/// merged into [values]) but not what is active now, like the real thing.
class FakeConfigSource implements RemoteConfigSource {
  /// Creates a source whose cached values are [values].
  FakeConfigSource(
    Map<String, Object?> values, {
    this.fetched = const {},
    this.activateBlock,
    this.activateError,
    this.fetchError,
  }) : values = {...values};

  /// What the next [activateCached] makes current.
  final Map<String, Object?> values;

  /// What [fetchForNextLaunch] adds to [values].
  final Map<String, Object?> fetched;

  /// When set, [activateCached] waits for it (a `Completer().future` never
  /// finishes).
  final Future<void>? activateBlock;

  /// When set, [activateCached] throws it.
  final Error? activateError;

  /// When set, [fetchForNextLaunch] throws it.
  final Error? fetchError;

  /// The calls received, in order: `activateCached`, `fetchForNextLaunch`.
  final List<String> calls = [];

  final Map<String, Object?> _active = {};

  @override
  Future<void> activateCached() async {
    calls.add('activateCached');
    await activateBlock;
    if (activateError != null) throw activateError!;
    _active
      ..clear()
      ..addAll(values);
  }

  @override
  Future<void> fetchForNextLaunch() async {
    calls.add('fetchForNextLaunch');
    if (fetchError != null) throw fetchError!;
    values.addAll(fetched);
  }

  @override
  Object? value(String key) => _active[key];
}
