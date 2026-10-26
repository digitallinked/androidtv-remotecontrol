import 'package:flutter/material.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';

/// The tile colours a user can pick for a custom shortcut, in the order they
/// are offered: Slate, Blue, Teal, Green, Amber, Orange, Red, Purple.
///
/// Our own palette, not any app's brand colours (Ruling P5-R4). The ink on
/// each is chosen by `colourKeyLabelColor` (in `tokens.dart`) and reaches
/// 4.5:1 contrast.
const List<Color> kShortcutColors = [
  Color(0xFF475569),
  Color(0xFF2563EB),
  Color(0xFF0F766E),
  Color(0xFF15803D),
  Color(0xFFF59E0B),
  Color(0xFFEA580C),
  Color(0xFFDC2626),
  Color(0xFF7C3AED),
];

/// The generic icons a user can pick for a custom shortcut, by the id that is
/// stored with the shortcut. Our own Material icons, never a brand logo.
const Map<String, IconData> kShortcutIcons = {
  'app': Icons.apps,
  'movies': Icons.movie_outlined,
  'live': Icons.live_tv_outlined,
  'sports': Icons.sports_soccer,
  'music': Icons.music_note_outlined,
  'kids': Icons.child_care_outlined,
  'news': Icons.newspaper_outlined,
  'games': Icons.sports_esports_outlined,
  'learning': Icons.school_outlined,
};

/// The spoken name of the swatch [c]. A colour that is not in
/// [kShortcutColors] is described as the default.
String shortcutColourName(AppLocalizations l, Color c) {
  final index = kShortcutColors.indexOf(c);
  return switch (index) {
    0 => l.shortcutColourSlate,
    1 => l.shortcutColourBlue,
    2 => l.shortcutColourTeal,
    3 => l.shortcutColourGreen,
    4 => l.shortcutColourAmber,
    5 => l.shortcutColourOrange,
    6 => l.shortcutColourRed,
    7 => l.shortcutColourPurple,
    _ => l.shortcutColourDefault,
  };
}

/// The name of the icon with [id]; an unknown id is named like the generic
/// `app` icon, which is what it draws.
String shortcutIconName(AppLocalizations l, String id) => switch (id) {
  'movies' => l.shortcutIconMovies,
  'live' => l.shortcutIconLive,
  'sports' => l.shortcutIconSports,
  'music' => l.shortcutIconMusic,
  'kids' => l.shortcutIconKids,
  'news' => l.shortcutIconNews,
  'games' => l.shortcutIconGames,
  'learning' => l.shortcutIconLearning,
  _ => l.shortcutIconApp,
};
