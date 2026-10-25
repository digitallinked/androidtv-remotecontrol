import 'package:tv_remote/core/storage/secure_key_value_store.dart';

/// A [SecureKeyValueStore] that keeps its values in a map, for tests.
class InMemorySecureKeyValueStore implements SecureKeyValueStore {
  /// The stored values; tests may read and edit it directly.
  final Map<String, String> values = {};

  /// When set, [read] throws this object.
  Object? throwOnRead;

  /// When set, [write] throws this object.
  Object? throwOnWrite;

  @override
  Future<String?> read(String key) async {
    final error = throwOnRead;
    // Tests inject arbitrary objects, e.g. a PlatformException.
    // ignore: only_throw_errors
    if (error != null) throw error;
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    final error = throwOnWrite;
    // Tests inject arbitrary objects, e.g. a PlatformException.
    // ignore: only_throw_errors
    if (error != null) throw error;
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
