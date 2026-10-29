import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/types.dart';

/// In-memory preferences whose every `set*` throws `StateError('write
/// failed')` while [failing] is true. Reads always work.
///
/// A store keeps the platform it opened on, so open the store on this one
/// (set `SharedPreferencesAsyncPlatform.instance` first), with [failing]
/// false if the test writes its starting settings, and turn [failing] on
/// once the screen is up.
base class FailingSharedPreferencesAsync
    extends InMemorySharedPreferencesAsync {
  /// Creates empty preferences that fail writes while [failing].
  FailingSharedPreferencesAsync({this.failing = true}) : super.empty();

  /// Whether writes throw.
  bool failing;

  Future<bool> _write(Future<bool> Function() write) async {
    if (failing) throw StateError('write failed');
    return write();
  }

  @override
  Future<bool> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) => _write(() => super.setString(key, value, options));

  @override
  Future<bool> setInt(
    String key,
    int value,
    SharedPreferencesOptions options,
  ) => _write(() => super.setInt(key, value, options));

  @override
  Future<bool> setDouble(
    String key,
    double value,
    SharedPreferencesOptions options,
  ) => _write(() => super.setDouble(key, value, options));

  @override
  Future<bool> setBool(
    String key,
    bool value,
    SharedPreferencesOptions options,
  ) => _write(() => super.setBool(key, value, options));

  @override
  Future<bool> setStringList(
    String key,
    List<String> value,
    SharedPreferencesOptions options,
  ) => _write(() => super.setStringList(key, value, options));
}
