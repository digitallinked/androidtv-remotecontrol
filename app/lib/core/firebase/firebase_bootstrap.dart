import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/config/service_config.dart';

part 'firebase_bootstrap.g.dart';

/// Whether Firebase is running in this build.
enum FirebaseStatus {
  /// `FIREBASE_ENABLED` is off: Firebase was never started.
  notConfigured,

  /// Firebase was asked to start and failed or timed out (a missing native
  /// config file, no Google Play services, or too slow).
  unavailable,

  /// Firebase is initialised.
  ready,
}

/// Starts Firebase when [config] enables it.
///
/// `Firebase.initializeApp()` reads the native config file
/// (`google-services.json` or `GoogleService-Info.plist`), so this is only
/// ever enabled in builds that have one (Ruling P6-R2). It never throws: a
/// failure or a [timeout] gives [FirebaseStatus.unavailable] and the app runs
/// on no-op services. [initializeApp] replaces the real call in tests.
Future<FirebaseStatus> initializeFirebase(
  ServiceConfig config, {
  Future<void> Function()? initializeApp,
  Duration timeout = const Duration(seconds: 5),
}) async {
  if (!config.firebaseEnabled) return FirebaseStatus.notConfigured;
  try {
    await Future.sync(initializeApp ?? _initializeApp).timeout(timeout);
    return FirebaseStatus.ready;
  } on Object catch (error) {
    // The crash reporter is not wired to Firebase yet; log only.
    developer.log('Firebase is unavailable', name: 'firebase', error: error);
    return FirebaseStatus.unavailable;
  }
}

Future<void> _initializeApp() async {
  await Firebase.initializeApp();
}

/// Whether Firebase started. Startup overrides it; tests get
/// [FirebaseStatus.notConfigured].
@Riverpod(keepAlive: true)
FirebaseStatus firebaseStatus(Ref ref) => FirebaseStatus.notConfigured;
