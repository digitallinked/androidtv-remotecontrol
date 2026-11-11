import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The link to send the TV for [link].
///
/// The owner's TV answers `market://launch?id=` (and `intent:` and
/// `android-app://` links) with an error and closes the connection, but it
/// opens `market://details?id=`: the app's Play Store page, with Open when the
/// app is installed and Install when it isn't (DM-029, 2026-11-11). Shortcuts
/// saved with the old link are mapped here, at launch, so none needs a
/// migration.
String tvLaunchLink(String link) {
  final uri = Uri.tryParse(link);
  if (uri == null || uri.scheme != 'market' || uri.host != 'launch') {
    return link;
  }
  final id = uri.queryParameters['id'];
  return id == null || id.isEmpty ? link : 'market://details?id=$id';
}

/// An app on the TV that the remote can open.
///
/// Brand names are data, not UI strings. The catalogue, icons and shortcuts
/// that fill these in come in Phase 5; Phase 4 only needs the model.
@immutable
class AppEntry {
  /// Creates an entry. [launchLink] defaults to the Play Store page of
  /// [package] on the TV (see [tvLaunchLink]).
  const AppEntry({
    required this.package,
    required this.name,
    String? launchLink,
    this.iconUrl,
    this.isCustom = false,
    this.customColor,
    this.customIcon,
  }) : launchLink = launchLink ?? 'market://details?id=$package';

  /// The Android application id, for example `com.netflix.ninja`.
  final String package;

  /// The name shown to the user.
  final String name;

  /// The deep link sent to the TV to open the app.
  final String launchLink;

  /// Where the app's icon can be loaded from, if known.
  final String? iconUrl;

  /// Whether the user added this entry (as opposed to the catalogue).
  final bool isCustom;

  /// The tile colour the user picked for a custom entry.
  final Color? customColor;

  /// The icon name the user picked for a custom entry.
  final String? customIcon;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppEntry &&
          other.package == package &&
          other.name == name &&
          other.launchLink == launchLink &&
          other.iconUrl == iconUrl &&
          other.isCustom == isCustom &&
          other.customColor == customColor &&
          other.customIcon == customIcon;

  @override
  int get hashCode => Object.hash(
    package,
    name,
    launchLink,
    iconUrl,
    isCustom,
    customColor,
    customIcon,
  );

  @override
  String toString() => 'AppEntry($package)';
}
