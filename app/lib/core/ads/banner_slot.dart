import 'package:flutter/widgets.dart';

/// Where a [BannerSlot] sits. Only these two screens ever have one.
enum AdPlacement {
  /// The Apps screen (`/apps`).
  apps,

  /// The Settings hub (`/settings`).
  settings,
}

/// The place for the banner ad (Ruling P5-R3).
///
/// It sits in `Scaffold.bottomNavigationBar` of exactly two screens, the Apps
/// screen and the Settings hub, and nowhere else: not on sub-pages, sheets,
/// the remote, discovery, pairing, onboarding or the paywall. Those two
/// screens have no bottom-anchored control, and their scroll views end with
/// [clearance] of padding.
///
/// In Phase 5 it builds nothing and takes no space. Phase 6.3 replaces
/// [build] with the real banner and keeps this constructor.
class BannerSlot extends StatelessWidget {
  /// Creates the slot for [placement].
  const BannerSlot({required this.placement, super.key});

  /// The screen the slot belongs to.
  final AdPlacement placement;

  /// Space a scroll view leaves at its end so the banner never covers
  /// content.
  static const double clearance = 48;

  @override
  Widget build(BuildContext context) =>
      SizedBox.shrink(key: ValueKey('banner_slot_${placement.name}'));
}
