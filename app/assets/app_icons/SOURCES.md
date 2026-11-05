# Where the app logos come from

The tiles of 27 catalogue apps draw these files (Ruling P9-C16). The other 28
apps keep the letter tile. Nothing comes from any other source, nothing comes
from the competitor or `docs/competitor-analysis/`, and no logo is drawn, traced
or approximated here.

- **Simple Icons 16.36.0:** npm package `simple-icons`, from
  https://registry.npmjs.org/simple-icons/-/simple-icons-16.36.0.tgz
  (SHA-1 `45f50dc2ec8fa7a14b68b6eb1b8ac1c1e4340772`). The package is released
  under CC0-1.0, and none of these rows has a per-icon licence entry in its data
  file. The URLs below serve the same files as that tarball.
- **selfh.st/icons:** https://github.com/selfhst/icons at commit
  `b2378abb1a0c64149bb7621815b849d89602de23` (2026-11-03), CC-BY-4.0. The
  repository's `LICENSE` is the unchanged Creative Commons text. Prime Video and
  Hulu use the repository's plain form, which is one colour. Disney+ and Peacock
  are multi-coloured in their plain form, so they use the `-light` form, the
  single-colour one that reads on a dark tile.

Every file is byte-for-byte the source file, renamed to the slug for the two
`-light` forms. The app tints each with the Ink colour below.

**Source colour** is the hex in Simple Icons' data, or the fill of the selfh.st
file. **Ink** is the same colour, or white when that colour is under 3:1 against
the tile `#141414`. A brand or store objection is answered by removing the row
from `app_logos.dart`.

App names and logos belong to their owners. These files are used only to name
the app a tile opens, and no owner endorses this app or has licensed the use.

| App | Package | File | Source | Version or commit | Licence | Original URL | Source colour | Ink |
|---|---|---|---|---|---|---|---|---|
| Netflix | `com.netflix.ninja` | `netflix.svg` | Simple Icons | 16.36.0 | CC0-1.0 | https://cdn.jsdelivr.net/npm/simple-icons@16.36.0/icons/netflix.svg | `#E50914` | `#E50914` |
| YouTube | `com.google.android.youtube.tv` | `youtube.svg` | Simple Icons | 16.36.0 | CC0-1.0 | https://cdn.jsdelivr.net/npm/simple-icons@16.36.0/icons/youtube.svg | `#FF0000` | `#FF0000` |
| Spotify | `com.spotify.tv.android` | `spotify.svg` | Simple Icons | 16.36.0 | CC0-1.0 | https://cdn.jsdelivr.net/npm/simple-icons@16.36.0/icons/spotify.svg | `#1ED760` | `#1ED760` |
| Apple TV | `com.apple.atve.androidtv.appletv` | `appletv.svg` | Simple Icons | 16.36.0 | CC0-1.0 | https://cdn.jsdelivr.net/npm/simple-icons@16.36.0/icons/appletv.svg | `#000000` | `#FFFFFF` |
| YouTube Kids | `com.google.android.youtube.tvkids` | `youtubekids.svg` | Simple Icons | 16.36.0 | CC0-1.0 | https://cdn.jsdelivr.net/npm/simple-icons@16.36.0/icons/youtubekids.svg | `#FF0000` | `#FF0000` |
| YouTube Music | `com.google.android.youtube.tvmusic` | `youtubemusic.svg` | Simple Icons | 16.36.0 | CC0-1.0 | https://cdn.jsdelivr.net/npm/simple-icons@16.36.0/icons/youtubemusic.svg | `#FF0000` | `#FF0000` |
| Plex | `com.plexapp.android` | `plex.svg` | Simple Icons | 16.36.0 | CC0-1.0 | https://cdn.jsdelivr.net/npm/simple-icons@16.36.0/icons/plex.svg | `#EBAF00` | `#EBAF00` |
| Kodi | `org.xbmc.kodi` | `kodi.svg` | Simple Icons | 16.36.0 | CC0-1.0 | https://cdn.jsdelivr.net/npm/simple-icons@16.36.0/icons/kodi.svg | `#17B2E7` | `#17B2E7` |
| VLC | `org.videolan.vlc` | `vlcmediaplayer.svg` | Simple Icons | 16.36.0 | CC0-1.0 | https://cdn.jsdelivr.net/npm/simple-icons@16.36.0/icons/vlcmediaplayer.svg | `#FF8800` | `#FF8800` |
| Crunchyroll | `com.crunchyroll.crunchyroid` | `crunchyroll.svg` | Simple Icons | 16.36.0 | CC0-1.0 | https://cdn.jsdelivr.net/npm/simple-icons@16.36.0/icons/crunchyroll.svg | `#FF5E00` | `#FF5E00` |
| GeForce NOW | `com.nvidia.geforcenow` | `nvidia.svg` | Simple Icons | 16.36.0 | CC0-1.0 | https://cdn.jsdelivr.net/npm/simple-icons@16.36.0/icons/nvidia.svg | `#76B900` | `#76B900` |
| ZDFmediathek | `com.zdf.android.mediathek` | `zdf.svg` | Simple Icons | 16.36.0 | CC0-1.0 | https://cdn.jsdelivr.net/npm/simple-icons@16.36.0/icons/zdf.svg | `#FA7D19` | `#FA7D19` |
| Twitch | `tv.twitch.android.app` | `twitch.svg` | Simple Icons | 16.36.0 | CC0-1.0 | https://cdn.jsdelivr.net/npm/simple-icons@16.36.0/icons/twitch.svg | `#9146FF` | `#9146FF` |
| DAZN | `com.dazn` | `dazn.svg` | Simple Icons | 16.36.0 | CC0-1.0 | https://cdn.jsdelivr.net/npm/simple-icons@16.36.0/icons/dazn.svg | `#F8F8F5` | `#F8F8F5` |
| Deezer | `deezer.android.tv` | `deezer.svg` | Simple Icons | 16.36.0 | CC0-1.0 | https://cdn.jsdelivr.net/npm/simple-icons@16.36.0/icons/deezer.svg | `#A238FF` | `#A238FF` |
| HBO Max | `com.wbd.stream` | `hbomax.svg` | Simple Icons | 16.36.0 | CC0-1.0 | https://cdn.jsdelivr.net/npm/simple-icons@16.36.0/icons/hbomax.svg | `#000000` | `#FFFFFF` |
| Tubi | `com.tubitv` | `tubi.svg` | Simple Icons | 16.36.0 | CC0-1.0 | https://cdn.jsdelivr.net/npm/simple-icons@16.36.0/icons/tubi.svg | `#7408FF` | `#FFFFFF` |
| Paramount+ | `com.cbs.ott` | `paramountplus.svg` | Simple Icons | 16.36.0 | CC0-1.0 | https://cdn.jsdelivr.net/npm/simple-icons@16.36.0/icons/paramountplus.svg | `#0064FF` | `#0064FF` |
| Channel 4 | `com.channel4.ondemand` | `channel4.svg` | Simple Icons | 16.36.0 | CC0-1.0 | https://cdn.jsdelivr.net/npm/simple-icons@16.36.0/icons/channel4.svg | `#AAFF89` | `#AAFF89` |
| ITVX | `air.ITVMobilePlayer` | `itvx.svg` | Simple Icons | 16.36.0 | CC0-1.0 | https://cdn.jsdelivr.net/npm/simple-icons@16.36.0/icons/itvx.svg | `#DEEB52` | `#DEEB52` |
| Viaplay | `com.viaplay.android` | `viaplay.svg` | Simple Icons | 16.36.0 | CC0-1.0 | https://cdn.jsdelivr.net/npm/simple-icons@16.36.0/icons/viaplay.svg | `#FE365F` | `#FE365F` |
| Steam Link | `com.valvesoftware.steamlink` | `steam.svg` | Simple Icons | 16.36.0 | CC0-1.0 | https://cdn.jsdelivr.net/npm/simple-icons@16.36.0/icons/steam.svg | `#000000` | `#FFFFFF` |
| Rakuten TV | `tv.wuaki` | `rakuten.svg` | Simple Icons | 16.36.0 | CC0-1.0 | https://cdn.jsdelivr.net/npm/simple-icons@16.36.0/icons/rakuten.svg | `#BF0000` | `#FFFFFF` |
| Prime Video | `com.amazon.amazonvideo.livingroom` | `amazon-prime-video.svg` | selfh.st/icons | `b2378abb1a0c` | CC-BY-4.0 | https://raw.githubusercontent.com/selfhst/icons/b2378abb1a0c64149bb7621815b849d89602de23/svg/amazon-prime-video.svg | `#0779FF` | `#0779FF` |
| Disney+ | `com.disney.disneyplus` | `disney-plus.svg` | selfh.st/icons | `b2378abb1a0c` | CC-BY-4.0 | https://raw.githubusercontent.com/selfhst/icons/b2378abb1a0c64149bb7621815b849d89602de23/svg/disney-plus-light.svg | `#FFFFFF` | `#FFFFFF` |
| Hulu | `com.hulu.livingroomplus` | `hulu.svg` | selfh.st/icons | `b2378abb1a0c` | CC-BY-4.0 | https://raw.githubusercontent.com/selfhst/icons/b2378abb1a0c64149bb7621815b849d89602de23/svg/hulu.svg | `#1CE783` | `#1CE783` |
| Peacock | `com.peacocktv.peacockandroid` | `peacock.svg` | selfh.st/icons | `b2378abb1a0c` | CC-BY-4.0 | https://raw.githubusercontent.com/selfhst/icons/b2378abb1a0c64149bb7621815b849d89602de23/svg/peacock-light.svg | `#FFFFFF` | `#FFFFFF` |
