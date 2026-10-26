import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';

part 'starter_apps.g.dart';

/// The apps shown in the quick-access row until Phase 5's catalogue exists
/// (Ruling P4-R9).
///
/// The package names are the usual Android TV ids of these apps and are
/// unverified on the owner's TV. Brand names are data, not UI strings, and the
/// tiles draw a letter, never a logo.
const List<AppEntry> kStarterApps = [
  AppEntry(package: 'com.netflix.ninja', name: 'Netflix'),
  AppEntry(package: 'com.google.android.youtube.tv', name: 'YouTube'),
  AppEntry(package: 'com.amazon.amazonvideo.livingroom', name: 'Prime Video'),
  AppEntry(package: 'com.disney.disneyplus', name: 'Disney+'),
  AppEntry(package: 'com.spotify.tv.android', name: 'Spotify'),
];

/// The apps in the remote's quick-access row.
///
/// Phase 5.1 replaces this body with the catalogue and the user's shortcuts;
/// until then it returns [kStarterApps].
@riverpod
List<AppEntry> quickAccessApps(Ref ref) => kStarterApps;
