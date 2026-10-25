import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'flavor.g.dart';

/// A build flavor of the app.
enum Flavor {
  /// Development build, installed beside the store app.
  dev(
    displayName: 'Remotely Dev',
    applicationId: 'com.digitallinked.atvremote.dev',
  ),

  /// Store build.
  prod(
    displayName: 'Remotely for Android TV',
    applicationId: 'com.digitallinked.atvremote',
  );

  const Flavor({required this.displayName, required this.applicationId});

  /// Name shown to the user.
  final String displayName;

  /// Android application id and iOS bundle id.
  final String applicationId;
}

/// Whether the Dart entry point's [flavor] agrees with the flavor the native
/// build was made with. A `null` [nativeFlavor] (no flavor passed to the
/// build) always agrees.
bool flavorMatchesNative(Flavor flavor, String? nativeFlavor) =>
    nativeFlavor == null || nativeFlavor == flavor.name;

/// The running flavor. Bootstrap must override it.
@Riverpod(keepAlive: true)
Flavor flavor(Ref ref) => throw UnimplementedError(
  'flavorProvider must be overridden at bootstrap',
);
