import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A small string key-value store whose contents are encrypted at rest.
abstract interface class SecureKeyValueStore {
  /// The value stored under [key], or `null` when there is none.
  Future<String?> read(String key);

  /// Stores [value] under [key], replacing any existing value.
  Future<void> write(String key, String value);

  /// Removes [key]; does nothing if it is not stored.
  Future<void> delete(String key);
}

/// [SecureKeyValueStore] backed by the platform keystore or keychain.
class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  /// Creates a store over the given secure storage.
  const FlutterSecureKeyValueStore([this._storage = defaultStorage]);

  /// The storage used by default.
  ///
  /// Android keeps the plugin defaults, which include `resetOnError: true`:
  /// a store that cannot be decrypted (for example after a restore onto a
  /// new phone) reads as empty instead of throwing. On iOS the keychain item
  /// is available after the first unlock and never leaves this device, so a
  /// backup restored onto another phone starts without the key.
  static const FlutterSecureStorage defaultStorage = FlutterSecureStorage(
    // Spelled out so the Android defaults (resetOnError) stay visible.
    // ignore: avoid_redundant_argument_values
    aOptions: AndroidOptions.defaultOptions,
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
