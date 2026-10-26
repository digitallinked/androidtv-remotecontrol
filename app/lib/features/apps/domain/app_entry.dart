import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// An app on the TV that the remote can open.
///
/// Brand names are data, not UI strings. The catalogue, icons and shortcuts
/// that fill these in come in Phase 5; Phase 4 only needs the model.
@immutable
class AppEntry {
  /// Creates an entry. [launchLink] defaults to the Play Store launch link
  /// of [package], which opens an installed app on the TV.
  const AppEntry({
    required this.package,
    required this.name,
    String? launchLink,
    this.iconUrl,
    this.isCustom = false,
    this.customColor,
    this.customIcon,
  }) : launchLink = launchLink ?? 'market://launch?id=$package';

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
