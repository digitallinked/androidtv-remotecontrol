import 'dart:developer' as developer;

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:tv_remote/core/config/app_config.dart';

/// [RemoteConfigSource] backed by `FirebaseRemoteConfig.instance`.
///
/// This is the only file that imports `firebase_remote_config`. Every call
/// catches everything, `MissingPluginException` included: a failing Remote
/// Config leaves the defaults in place and never becomes a crash.
class FirebaseRemoteConfigSource implements RemoteConfigSource {
  /// Creates the source. It touches Firebase only when a method is called.
  FirebaseRemoteConfigSource({required this.minimumFetchInterval});

  /// How old fetched values may be before [fetchForNextLaunch] downloads
  /// again.
  final Duration minimumFetchInterval;

  FirebaseRemoteConfig? _instance;

  @override
  Future<void> activateCached() async {
    try {
      final config = _instance = FirebaseRemoteConfig.instance;
      await config.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: minimumFetchInterval,
        ),
      );
      await config.setDefaults(AppConfigValues.defaultsMap);
      await config.ensureInitialized();
      await config.activate();
    } on Object catch (error) {
      _log('activate failed', error);
    }
  }

  @override
  Future<void> fetchForNextLaunch() async {
    try {
      await (_instance ?? FirebaseRemoteConfig.instance).fetch();
    } on Object catch (error) {
      _log('fetch failed', error);
    }
  }

  @override
  Object? value(String key) {
    final fallback = AppConfigValues.defaultsMap[key];
    final config = _instance;
    if (fallback == null || config == null) return null;
    try {
      final value = config.getValue(key);
      if (value.source == ValueSource.valueStatic) return null;
      return parseRemoteConfigText(fallback, value.asString());
    } on Object catch (error) {
      _log('read $key failed', error);
      return null;
    }
  }

  void _log(String what, Object error) =>
      developer.log('Remote Config $what', name: 'config', error: error);
}

/// Reads [text] as the type of [fallback] (a `bool`, an `int` or a `String`),
/// or returns `null` when it doesn't read as one.
///
/// The plugin's own `asInt` and `asBool` turn text that isn't a number or a
/// flag into `0` and `false`, which would hide a mistyped console value; this
/// keeps the difference so the key falls back to its default.
@visibleForTesting
Object? parseRemoteConfigText(Object fallback, String text) {
  final trimmed = text.trim();
  return switch (fallback) {
    bool() => switch (trimmed.toLowerCase()) {
      'true' || '1' => true,
      'false' || '0' => false,
      _ => null,
    },
    int() => int.tryParse(trimmed),
    String() => text,
    _ => null,
  };
}
