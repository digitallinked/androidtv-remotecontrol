import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';

/// The fill of every logo tile, in both themes (Ruling P9-C16). It is
/// brand art, not a theme token, so a logo's colour is never changed by the
/// tile it sits on.
const Color kAppLogoTile = Color(0xFF141414);

/// The logo of one app: a bundled file, the tile under it and its ink.
@immutable
class AppLogo {
  /// Creates a logo drawn from [asset] in [ink] on [fill].
  const AppLogo({
    required this.asset,
    required this.ink,
    this.fill = kAppLogoTile,
  });

  /// The bundled SVG. `assets/app_icons/SOURCES.md` says where it came from.
  final String asset;

  /// The colour of the tile.
  final Color fill;

  /// The colour the logo is drawn in: the brand's own, or white when that
  /// is under 3:1 against [fill].
  final Color ink;
}

/// The apps that draw a logo, by package. The other catalogue apps keep the
/// letter tile. A brand or store objection is answered by removing the row
/// (Ruling P9-C16).
const Map<String, AppLogo> kAppLogos = {
  'com.amazon.amazonvideo.livingroom': AppLogo(
    asset: 'assets/app_icons/amazon-prime-video.svg',
    ink: Color(0xFF0779FF),
  ),
  'com.apple.atve.androidtv.appletv': AppLogo(
    asset: 'assets/app_icons/appletv.svg',
    ink: Color(0xFFFFFFFF),
  ),
  'com.channel4.ondemand': AppLogo(
    asset: 'assets/app_icons/channel4.svg',
    ink: Color(0xFFAAFF89),
  ),
  'com.crunchyroll.crunchyroid': AppLogo(
    asset: 'assets/app_icons/crunchyroll.svg',
    ink: Color(0xFFFF5E00),
  ),
  'com.dazn': AppLogo(
    asset: 'assets/app_icons/dazn.svg',
    ink: Color(0xFFF8F8F5),
  ),
  'deezer.android.tv': AppLogo(
    asset: 'assets/app_icons/deezer.svg',
    ink: Color(0xFFA238FF),
  ),
  'com.disney.disneyplus': AppLogo(
    asset: 'assets/app_icons/disney-plus.svg',
    ink: Color(0xFFFFFFFF),
  ),
  'com.nvidia.geforcenow': AppLogo(
    asset: 'assets/app_icons/nvidia.svg',
    ink: Color(0xFF76B900),
  ),
  'com.wbd.stream': AppLogo(
    asset: 'assets/app_icons/hbomax.svg',
    ink: Color(0xFFFFFFFF),
  ),
  'com.hulu.livingroomplus': AppLogo(
    asset: 'assets/app_icons/hulu.svg',
    ink: Color(0xFF1CE783),
  ),
  'air.ITVMobilePlayer': AppLogo(
    asset: 'assets/app_icons/itvx.svg',
    ink: Color(0xFFDEEB52),
  ),
  'org.xbmc.kodi': AppLogo(
    asset: 'assets/app_icons/kodi.svg',
    ink: Color(0xFF17B2E7),
  ),
  'com.netflix.ninja': AppLogo(
    asset: 'assets/app_icons/netflix.svg',
    ink: Color(0xFFE50914),
  ),
  'com.cbs.ott': AppLogo(
    asset: 'assets/app_icons/paramountplus.svg',
    ink: Color(0xFF0064FF),
  ),
  'com.peacocktv.peacockandroid': AppLogo(
    asset: 'assets/app_icons/peacock.svg',
    ink: Color(0xFFFFFFFF),
  ),
  'com.plexapp.android': AppLogo(
    asset: 'assets/app_icons/plex.svg',
    ink: Color(0xFFEBAF00),
  ),
  'tv.wuaki': AppLogo(
    asset: 'assets/app_icons/rakuten.svg',
    ink: Color(0xFFFFFFFF),
  ),
  'com.spotify.tv.android': AppLogo(
    asset: 'assets/app_icons/spotify.svg',
    ink: Color(0xFF1ED760),
  ),
  'com.valvesoftware.steamlink': AppLogo(
    asset: 'assets/app_icons/steam.svg',
    ink: Color(0xFFFFFFFF),
  ),
  'com.tubitv': AppLogo(
    asset: 'assets/app_icons/tubi.svg',
    ink: Color(0xFFFFFFFF),
  ),
  'tv.twitch.android.app': AppLogo(
    asset: 'assets/app_icons/twitch.svg',
    ink: Color(0xFF9146FF),
  ),
  'com.viaplay.android': AppLogo(
    asset: 'assets/app_icons/viaplay.svg',
    ink: Color(0xFFFE365F),
  ),
  'org.videolan.vlc': AppLogo(
    asset: 'assets/app_icons/vlcmediaplayer.svg',
    ink: Color(0xFFFF8800),
  ),
  'com.google.android.youtube.tv': AppLogo(
    asset: 'assets/app_icons/youtube.svg',
    ink: Color(0xFFFF0000),
  ),
  'com.google.android.youtube.tvkids': AppLogo(
    asset: 'assets/app_icons/youtubekids.svg',
    ink: Color(0xFFFF0000),
  ),
  'com.google.android.youtube.tvmusic': AppLogo(
    asset: 'assets/app_icons/youtubemusic.svg',
    ink: Color(0xFFFF0000),
  ),
  'com.zdf.android.mediathek': AppLogo(
    asset: 'assets/app_icons/zdf.svg',
    ink: Color(0xFFFA7D19),
  ),
};

/// The logo the square of [app] draws: the one of its package, for catalogue
/// apps and custom shortcuts alike, unless the user styled the entry.
AppLogo? appLogoOf(AppEntry app) =>
    app.customColor != null || app.customIcon != null
    ? null
    : kAppLogos[app.package];
